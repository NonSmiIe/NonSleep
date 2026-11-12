import NonSleepCore
import SwiftUI

@main
struct NonSleepApp: App {
    @StateObject private var model = HelperModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.status?.enabled == true ? "sun.max.fill" : "moon.zzz")
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: HelperModel

    var body: some View {
        if let status = model.status {
            Toggle("Stay awake with lid closed", isOn: Binding(
                get: { status.enabled },
                set: { model.setEnabled($0) }
            ))
            if let reason = status.stopReason {
                Text(stopText(reason, status: status))
            }
            Text(sensorText(status.sensors))
            if let error = status.error {
                Text("Error: \(error)")
            }
            Divider()
            Picker("Sleep when battery drops to", selection: Binding(
                get: { status.batteryThreshold },
                set: { model.setBatteryThreshold($0) }
            )) {
                ForEach(NonSleepConstants.batteryThresholdChoices, id: \.self) { percent in
                    Text("\(percent)%").tag(percent)
                }
            }
        } else {
            Text("Helper is not running")
            Text("Run scripts/install.sh from the NonSleep repository")
        }
        Divider()
        Button("Quit NonSleep") { NSApplication.shared.terminate(nil) }
    }

    private func stopText(_ reason: StopReason, status: Status) -> String {
        switch reason {
        case .battery: "Turned off: battery dropped to \(status.batteryThreshold)%"
        case .heat: "Turned off: the Mac got too hot"
        }
    }

    private func sensorText(_ sensors: Sensors) -> String {
        var parts: [String] = []
        if let percent = sensors.batteryPercent {
            parts.append("Battery \(percent)%" + (sensors.onBattery ? "" : ", charging"))
        }
        if let temperature = sensors.batteryTemperature {
            parts.append(String(format: "%.0f °C", temperature))
        }
        return parts.isEmpty ? "No battery" : parts.joined(separator: " · ")
    }
}

/// Talks to the root helper and keeps its latest status for the menu.
final class HelperModel: ObservableObject {
    @Published var status: Status?

    private var connection: NSXPCConnection?
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        helper()?.status(reply: receive)
    }

    func setEnabled(_ enabled: Bool) {
        helper()?.setEnabled(enabled, reply: receive)
    }

    func setBatteryThreshold(_ percent: Int) {
        helper()?.setBatteryThreshold(percent, reply: receive)
    }

    private func helper() -> HelperProtocol? {
        if connection == nil {
            let created = NSXPCConnection(
                machServiceName: NonSleepConstants.helperLabel, options: .privileged)
            created.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            created.invalidationHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.connection = nil
                    self?.status = nil
                }
            }
            created.resume()
            connection = created
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async { self?.status = nil }
        } as? HelperProtocol
    }

    private func receive(_ data: Data) {
        let decoded = try? JSONDecoder().decode(Status.self, from: data)
        DispatchQueue.main.async { self.status = decoded }
    }
}

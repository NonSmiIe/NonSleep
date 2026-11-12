import NonSleepCore
import SwiftUI

struct NonSleepApp: App {
    @StateObject private var model = HelperModel()

    var body: some Scene {
        MenuBarExtra {
            PanelView(
                status: model.status,
                setEnabled: model.setEnabled,
                setBatteryThreshold: model.setBatteryThreshold
            )
            .onAppear(perform: model.refresh)
        } label: {
            Image(nsImage: EyeIcon.image(open: model.status?.enabled == true, width: 20))
        }
        .menuBarExtraStyle(.window)
    }
}

/// Talks to the root helper and keeps its latest status for the panel.
final class HelperModel: ObservableObject {
    @Published var status: Status?

    private var connection: NSXPCConnection?
    private var timer: Timer?

    init() {
        refresh()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
        // Common modes, so the status keeps updating while the panel is being used.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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

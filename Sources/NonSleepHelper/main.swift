import Foundation
import NonSleepCore
import SystemConfiguration

/// Root helper of NonSleep. Launched by launchd; the menu bar app talks to it over XPC.
///   --probe   print the sensor readings and exit (no root needed)
///   --reset   switch the mode off, restore the settings and exit (used by uninstall)

let stateURL = URL(fileURLWithPath: "/Library/Application Support/NonSleep/state.json")

func loadState() -> Controller.State {
    guard let data = try? Data(contentsOf: stateURL),
          let state = try? JSONDecoder().decode(Controller.State.self, from: data)
    else { return Controller.State() }
    return state
}

func saveState(_ state: Controller.State) {
    do {
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
    } catch {
        NSLog("NonSleep: cannot save state: \(error.localizedDescription)")
    }
}

final class Service: NSObject, HelperProtocol, NSXPCListenerDelegate {
    private let queue = DispatchQueue(label: "com.nonsmile.nonsleep.helper")
    private let controller = Controller(system: MacPowerSystem(), state: loadState(), persist: saveState)
    private var timer: DispatchSourceTimer?

    func start() {
        queue.sync {
            controller.start()
            syncTimer()
        }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Only root and the user sitting at the Mac may control sleep.
        var consoleUser: uid_t = 0
        _ = SCDynamicStoreCopyConsoleUser(nil, &consoleUser, nil)
        let caller = connection.effectiveUserIdentifier
        guard caller == 0 || caller == consoleUser else { return false }
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func status(reply: @escaping (Data) -> Void) {
        queue.async { reply(self.encodedStatus()) }
    }

    func setEnabled(_ enabled: Bool, reply: @escaping (Data) -> Void) {
        queue.async {
            self.controller.setEnabled(enabled)
            self.syncTimer()
            reply(self.encodedStatus())
        }
    }

    func setBatteryThreshold(_ percent: Int, reply: @escaping (Data) -> Void) {
        queue.async {
            self.controller.setBatteryThreshold(percent)
            self.syncTimer()
            reply(self.encodedStatus())
        }
    }

    private func encodedStatus() -> Data {
        (try? JSONEncoder().encode(controller.status())) ?? Data()
    }

    /// The watchdog runs only while the mode is on.
    private func syncTimer() {
        if controller.state.enabled, timer == nil {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 5, repeating: 5, leeway: .seconds(1))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                self.controller.tick()
                self.syncTimer()
            }
            timer.resume()
            self.timer = timer
        } else if !controller.state.enabled, let running = timer {
            running.cancel()
            timer = nil
        }
    }
}

let arguments = CommandLine.arguments.dropFirst()

if arguments.contains("--probe") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(MacPowerSystem().sensors()), as: UTF8.self))
    exit(0)
}

guard getuid() == 0 else {
    FileHandle.standardError.write(Data("nonsleep helper must run as root\n".utf8))
    exit(1)
}

if arguments.contains("--reset") {
    let controller = Controller(system: MacPowerSystem(), state: loadState(), persist: saveState)
    controller.setEnabled(false)
    if let error = controller.status().error {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(1)
    }
    exit(0)
}

let service = Service()
service.start()
let listener = NSXPCListener(machServiceName: NonSleepConstants.helperLabel)
listener.delegate = service
listener.resume()
dispatchMain()

import Foundation

/// What the controller needs from the machine.
public protocol PowerSystem {
    func sensors() -> Sensors
    /// Runs `pmset` with the arguments and returns its output.
    @discardableResult func pmset(_ arguments: [String]) throws -> String
}

public enum Safety {
    /// The reason to stop staying awake right now, if there is one.
    public static func stopReason(sensors: Sensors, batteryThreshold: Int) -> StopReason? {
        if sensors.thermalPressureHigh { return .heat }
        if let temperature = sensors.batteryTemperature,
           temperature >= NonSleepConstants.batteryTemperatureLimit {
            return .heat
        }
        if sensors.onBattery, let percent = sensors.batteryPercent, percent <= batteryThreshold {
            return .battery
        }
        return nil
    }
}

/// Owns the "stay awake with the lid closed" mode: the system sleep switch, low power
/// while the lid is closed, and the battery and heat cut-offs. Not thread-safe: call it
/// from one queue.
public final class Controller {
    public struct State: Codable, Equatable {
        public var enabled = false
        public var batteryThreshold = NonSleepConstants.defaultBatteryThreshold
        public var stopReason: StopReason?
        /// Set while the controller holds the Mac in low power; the values to put back.
        public var savedPowerMode: SavedPowerMode?

        public init() {}
    }

    public private(set) var state: State
    private let system: PowerSystem
    private let persist: (State) -> Void
    private var sleepDisabledApplied: Bool?
    private var powerModeUnsupported = false
    private var lastError: String?

    public init(system: PowerSystem, state: State, persist: @escaping (State) -> Void) {
        self.system = system
        self.state = state
        self.persist = persist
    }

    /// Brings the machine in line with the stored state. Call once after launch.
    public func start() {
        if state.enabled { tick() } else { apply(sensors: system.sensors()) }
    }

    public func setEnabled(_ enabled: Bool) {
        state.enabled = enabled
        state.stopReason = nil
        if enabled { tick() } else { apply(sensors: system.sensors()) }
    }

    public func setBatteryThreshold(_ percent: Int) {
        guard NonSleepConstants.batteryThresholdChoices.contains(percent) else { return }
        state.batteryThreshold = percent
        if state.enabled { tick() } else { persist(state) }
    }

    /// Periodic check while the mode is on: cut-offs first, then lid changes.
    public func tick() {
        guard state.enabled else { return }
        let sensors = system.sensors()
        if let reason = Safety.stopReason(sensors: sensors, batteryThreshold: state.batteryThreshold) {
            state.enabled = false
            state.stopReason = reason
            apply(sensors: sensors)
            if sensors.lidClosed {
                // Nobody is at the Mac to put it to sleep, and sleep is allowed again.
                run(["sleepnow"])
            }
            return
        }
        apply(sensors: sensors)
    }

    public func status() -> Status {
        Status(
            enabled: state.enabled,
            batteryThreshold: state.batteryThreshold,
            stopReason: state.stopReason,
            sensors: system.sensors(),
            error: lastError
        )
    }

    private func apply(sensors: Sensors) {
        lastError = nil
        if state.enabled {
            setSleepDisabled(true, sensors: sensors)
            if sensors.lidClosed { enterLowPower() } else { leaveLowPower() }
        } else {
            leaveLowPower()
            setSleepDisabled(false, sensors: sensors)
        }
        persist(state)
    }

    /// Goes by the switch as the system reports it, so a change made behind our back
    /// (another tool, a system update) is put right on the next tick.
    private func setSleepDisabled(_ disabled: Bool, sensors: Sensors) {
        guard (sensors.sleepDisabled ?? sleepDisabledApplied) != disabled else { return }
        if run(["-a", "disablesleep", disabled ? "1" : "0"]) != nil {
            sleepDisabledApplied = disabled
        }
    }

    private func enterLowPower() {
        guard state.savedPowerMode == nil, !powerModeUnsupported else { return }
        guard let output = run(["-g", "custom"]) else { return }
        guard let current = SavedPowerMode.parse(pmsetCustom: output) else {
            powerModeUnsupported = true
            return
        }
        if run(current.lowPowerCommand) != nil {
            state.savedPowerMode = current
        }
    }

    private func leaveLowPower() {
        guard let saved = state.savedPowerMode else { return }
        var restored = true
        for command in saved.restoreCommands where run(command) == nil {
            restored = false
        }
        if restored { state.savedPowerMode = nil }
    }

    @discardableResult
    private func run(_ arguments: [String]) -> String? {
        do {
            return try system.pmset(arguments)
        } catch {
            lastError = "pmset \(arguments.joined(separator: " ")): \(error.localizedDescription)"
            return nil
        }
    }
}

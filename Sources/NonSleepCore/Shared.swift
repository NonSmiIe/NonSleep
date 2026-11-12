import Foundation

public enum NonSleepConstants {
    /// Mach service the root helper listens on, and its launchd label.
    public static let helperLabel = "com.nonsmile.nonsleep.helper"
    public static let batteryThresholdChoices = [10, 20, 30, 40, 50]
    public static let defaultBatteryThreshold = 20
    /// Battery temperature (°C) at which staying awake is stopped.
    public static let batteryTemperatureLimit = 45.0
}

/// Why the helper switched the mode off by itself.
public enum StopReason: String, Codable {
    case battery
    case heat
}

public struct Sensors: Codable, Equatable {
    public var lidClosed: Bool
    public var onBattery: Bool
    public var batteryPercent: Int?
    public var batteryTemperature: Double?
    /// macOS reports serious or critical thermal pressure.
    public var thermalPressureHigh: Bool
    /// The system's "sleep disabled" switch as it is right now; nil when it cannot be read.
    public var sleepDisabled: Bool?

    public init(
        lidClosed: Bool,
        onBattery: Bool,
        batteryPercent: Int?,
        batteryTemperature: Double?,
        thermalPressureHigh: Bool,
        sleepDisabled: Bool? = nil
    ) {
        self.lidClosed = lidClosed
        self.onBattery = onBattery
        self.batteryPercent = batteryPercent
        self.batteryTemperature = batteryTemperature
        self.thermalPressureHigh = thermalPressureHigh
        self.sleepDisabled = sleepDisabled
    }
}

public struct Status: Codable, Equatable {
    public var enabled: Bool
    public var batteryThreshold: Int
    public var stopReason: StopReason?
    public var sensors: Sensors
    public var error: String?

    public init(
        enabled: Bool,
        batteryThreshold: Int,
        stopReason: StopReason? = nil,
        sensors: Sensors,
        error: String? = nil
    ) {
        self.enabled = enabled
        self.batteryThreshold = batteryThreshold
        self.stopReason = stopReason
        self.sensors = sensors
        self.error = error
    }
}

/// XPC interface of the root helper. Every reply carries a JSON-encoded `Status`.
@objc public protocol HelperProtocol {
    func status(reply: @escaping (Data) -> Void)
    func setEnabled(_ enabled: Bool, reply: @escaping (Data) -> Void)
    func setBatteryThreshold(_ percent: Int, reply: @escaping (Data) -> Void)
}

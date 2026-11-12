import Foundation

/// The energy-mode setting of both power sources, as it was before the lid closed.
public struct SavedPowerMode: Codable, Equatable {
    /// `powermode` on Macs with an Energy Mode picker, `lowpowermode` on the others.
    public var key: String
    public var battery: Int?
    public var ac: Int?

    public init(key: String, battery: Int?, ac: Int?) {
        self.key = key
        self.battery = battery
        self.ac = ac
    }

    /// Reads the setting out of `pmset -g custom`. Nil when this Mac has no such setting.
    public static func parse(pmsetCustom output: String) -> SavedPowerMode? {
        var section: String?
        var values: [String: [String: Int]] = [:]
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") {
                section = String(trimmed.dropLast())
                continue
            }
            guard let section else { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count == 2, let value = Int(parts[1]) else { continue }
            let key = String(parts[0])
            guard key == "powermode" || key == "lowpowermode" else { continue }
            values[key, default: [:]][section] = value
        }
        for key in ["powermode", "lowpowermode"] {
            if let found = values[key] {
                return SavedPowerMode(key: key, battery: found["Battery Power"], ac: found["AC Power"])
            }
        }
        return nil
    }

    /// pmset arguments that switch both power sources to low power.
    public var lowPowerCommand: [String] { ["-a", key, "1"] }

    /// pmset invocations that put the saved values back.
    public var restoreCommands: [[String]] {
        var commands: [[String]] = []
        if let battery { commands.append(["-b", key, String(battery)]) }
        if let ac { commands.append(["-c", key, String(ac)]) }
        return commands
    }
}

import Foundation
import IOKit
import IOKit.ps
import NonSleepCore

struct PmsetError: LocalizedError {
    let output: String
    var errorDescription: String? { output }
}

/// The real machine: IOKit for the sensors, `/usr/bin/pmset` for the settings.
struct MacPowerSystem: PowerSystem {
    func sensors() -> Sensors {
        let battery = batteryState()
        return Sensors(
            lidClosed: registryValue(service: "IOPMrootDomain", key: "AppleClamshellState") as? Bool ?? false,
            onBattery: battery.onBattery,
            batteryPercent: battery.percent,
            batteryTemperature: (registryValue(service: "AppleSmartBattery", key: "Temperature") as? Int)
                .map { Double($0) / 100 },
            thermalPressureHigh: [.serious, .critical].contains(ProcessInfo.processInfo.thermalState),
            sleepDisabled: registryValue(service: "IOPMrootDomain", key: "SleepDisabled") as? Bool
        )
    }

    func pmset(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw PmsetError(output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private func registryValue(service: String, key: String) -> Any? {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(service))
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        return IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }

    private func batteryState() -> (onBattery: Bool, percent: Int?) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return (false, nil) }
        let providing = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        let onBattery = providing == kIOPMBatteryPowerKey
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                let current = info[kIOPSCurrentCapacityKey] as? Int,
                let max = info[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return (onBattery, current * 100 / max)
        }
        return (onBattery, nil)
    }
}

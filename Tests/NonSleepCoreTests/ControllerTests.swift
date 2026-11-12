import XCTest
@testable import NonSleepCore

final class FakeSystem: PowerSystem {
    var current = Sensors(
        lidClosed: false, onBattery: true, batteryPercent: 80,
        batteryTemperature: 30, thermalPressureHigh: false)
    var custom = """
        Battery Power:
         powermode            0
         sleep                1
        AC Power:
         powermode            2
         sleep                1
        """
    var commands: [[String]] = []
    var failing = false

    func sensors() -> Sensors { current }

    func pmset(_ arguments: [String]) throws -> String {
        if failing { throw NSError(domain: "pmset", code: 1) }
        commands.append(arguments)
        return arguments == ["-g", "custom"] ? custom : ""
    }
}

final class ControllerTests: XCTestCase {
    private var system: FakeSystem!
    private var saved: Controller.State!
    private var controller: Controller!

    override func setUp() {
        system = FakeSystem()
        saved = nil
        controller = Controller(system: system, state: .init()) { [unowned self] in saved = $0 }
    }

    func testParsesPowerModeOfBothSources() {
        XCTAssertEqual(
            SavedPowerMode.parse(pmsetCustom: system.custom),
            SavedPowerMode(key: "powermode", battery: 0, ac: 2))
        XCTAssertEqual(
            SavedPowerMode.parse(pmsetCustom: "Battery Power:\n lowpowermode 1\n sleep 1\n"),
            SavedPowerMode(key: "lowpowermode", battery: 1, ac: nil))
        XCTAssertNil(SavedPowerMode.parse(pmsetCustom: "AC Power:\n sleep 1\n"))
    }

    func testEnablingDisablesSleepOnce() {
        controller.setEnabled(true)
        controller.tick()
        controller.tick()
        XCTAssertEqual(system.commands, [["-a", "disablesleep", "1"]])
        XCTAssertEqual(saved.enabled, true)
    }

    func testLidCloseEntersLowPowerAndLidOpenRestores() {
        controller.setEnabled(true)
        system.commands = []
        system.current.lidClosed = true
        controller.tick()
        controller.tick()
        XCTAssertEqual(system.commands, [["-g", "custom"], ["-a", "powermode", "1"]])
        XCTAssertEqual(saved.savedPowerMode, SavedPowerMode(key: "powermode", battery: 0, ac: 2))

        system.commands = []
        system.current.lidClosed = false
        controller.tick()
        XCTAssertEqual(system.commands, [["-b", "powermode", "0"], ["-c", "powermode", "2"]])
        XCTAssertNil(saved.savedPowerMode)
    }

    func testLowBatteryStopsRestoresAndSleeps() {
        controller.setEnabled(true)
        system.current.lidClosed = true
        controller.tick()
        system.commands = []
        system.current.batteryPercent = 20
        controller.tick()
        XCTAssertEqual(system.commands, [
            ["-b", "powermode", "0"], ["-c", "powermode", "2"],
            ["-a", "disablesleep", "0"], ["sleepnow"],
        ])
        XCTAssertEqual(controller.status().enabled, false)
        XCTAssertEqual(controller.status().stopReason, .battery)
    }

    func testLowBatteryOnChargerDoesNotStop() {
        system.current.onBattery = false
        system.current.batteryPercent = 5
        controller.setEnabled(true)
        XCTAssertEqual(controller.status().enabled, true)
    }

    func testHeatStopsWithoutForcingSleepWhenLidIsOpen() {
        controller.setEnabled(true)
        system.commands = []
        system.current.batteryTemperature = 45
        controller.tick()
        XCTAssertEqual(system.commands, [["-a", "disablesleep", "0"]])
        XCTAssertEqual(controller.status().stopReason, .heat)

        controller.setEnabled(false)
        system.current.batteryTemperature = 30
        system.current.thermalPressureHigh = true
        controller.setEnabled(true)
        XCTAssertEqual(controller.status().stopReason, .heat)
    }

    func testStartClearsStickyFlagAndRestoresPowerModeAfterCrash() {
        var state = Controller.State()
        state.savedPowerMode = SavedPowerMode(key: "powermode", battery: 0, ac: 2)
        controller = Controller(system: system, state: state) { [unowned self] in saved = $0 }
        controller.start()
        XCTAssertEqual(system.commands, [
            ["-b", "powermode", "0"], ["-c", "powermode", "2"], ["-a", "disablesleep", "0"],
        ])
        XCTAssertNil(saved.savedPowerMode)
    }

    func testPmsetFailureIsReportedAndRetried() {
        system.failing = true
        controller.setEnabled(true)
        XCTAssertNotNil(controller.status().error)
        system.failing = false
        controller.tick()
        XCTAssertEqual(system.commands, [["-a", "disablesleep", "1"]])
        XCTAssertNil(controller.status().error)
    }

    func testThresholdAcceptsOnlyOfferedChoices() {
        controller.setBatteryThreshold(30)
        controller.setBatteryThreshold(99)
        XCTAssertEqual(controller.status().batteryThreshold, 30)
    }
}

import NonSleepCore
import SwiftUI

enum Palette {
    /// The one accent: the colour of "awake".
    static let awake = Color(red: 0.98, green: 0.74, blue: 0.18)
    static let onAwake = Color.black.opacity(0.85)
    static let tile = Color.primary.opacity(0.07)
}

/// The panel under the menu bar icon. Takes plain values, so it renders the same in
/// the app and in the README snapshot.
struct PanelView: View {
    let status: Status?
    let setEnabled: (Bool) -> Void
    let setBatteryThreshold: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let status {
                header(status)
                if let notice = notice(status) {
                    NoticeView(text: notice)
                }
                stats(status.sensors)
                threshold(status)
            } else {
                missingHelper
            }
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private func header(_ status: Status) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(status.enabled ? Palette.awake : Palette.tile)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(nsImage: EyeIcon.image(open: status.enabled, width: 26))
                        .renderingMode(.template)
                        .foregroundStyle(status.enabled ? AnyShapeStyle(Palette.onAwake) : AnyShapeStyle(.secondary))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("NonSleep")
                    .font(.system(size: 15, weight: .semibold))
                Text(status.enabled ? "Awake with the lid closed" : "Sleeps when the lid closes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            EyeSwitch(isOn: status.enabled) { setEnabled(!status.enabled) }
        }
    }

    private func notice(_ status: Status) -> String? {
        if let error = status.error { return error }
        switch status.stopReason {
        case .battery: return "Turned off: battery dropped to \(status.batteryThreshold)%"
        case .heat: return "Turned off: the Mac got too hot"
        case nil: return nil
        }
    }

    private func stats(_ sensors: Sensors) -> some View {
        HStack(spacing: 8) {
            StatTile(
                symbol: sensors.onBattery ? "battery.75percent" : "bolt.fill",
                caption: sensors.onBattery ? "On battery" : "Plugged in",
                value: sensors.batteryPercent.map { "\($0)%" } ?? "n/a")
            StatTile(
                symbol: "thermometer.medium",
                caption: "Battery temp",
                value: sensors.batteryTemperature.map { String(format: "%.0f°C", $0) } ?? "n/a")
            StatTile(
                symbol: "laptopcomputer",
                caption: "Lid",
                value: sensors.lidClosed ? "Closed" : "Open")
        }
    }

    private func threshold(_ status: Status) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep when battery drops to")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(NonSleepConstants.batteryThresholdChoices, id: \.self) { percent in
                    let selected = percent == status.batteryThreshold
                    Button { setBatteryThreshold(percent) } label: {
                        Text("\(percent)%")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(selected ? AnyShapeStyle(Palette.onAwake) : AnyShapeStyle(.primary))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                selected ? Palette.awake : Palette.tile,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var missingHelper: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Helper is not running")
                .font(.system(size: 15, weight: .semibold))
            Text("NonSleep needs its helper to control sleep. Run this in the NonSleep folder:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(installCommand)
                    .font(.system(size: 12, design: .monospaced))
                Spacer(minLength: 0)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(installCommand, forType: .string)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
            }
            .padding(10)
            .background(Palette.tile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var installCommand: String { "./scripts/install.sh" }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            if status != nil {
                Text("Low Power turns on while the lid is closed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// A switch whose knob carries the eye: it opens as the knob slides on.
struct EyeSwitch: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? Palette.awake : Color.primary.opacity(0.16))
                .frame(width: 54, height: 30)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(nsImage: EyeIcon.image(open: isOn, width: 15))
                                .renderingMode(.template)
                                .foregroundStyle(Palette.onAwake)
                        }
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: isOn)
        .accessibilityLabel("Stay awake with lid closed")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

struct StatTile: View {
    let symbol: String
    let caption: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 14)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Palette.tile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NoticeView: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Palette.awake)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Palette.awake.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

import NonSleepCore
import SwiftUI

/// Renders the panel in its states, and the menu bar icon, to PNG files for the README.
@MainActor
enum Snapshot {
    static func render(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for scheme in [ColorScheme.dark, .light] {
            let name = scheme == .dark ? "panel-dark.png" : "panel-light.png"
            write(sheet.environment(\.colorScheme, scheme), to: folder.appendingPathComponent(name))
        }
    }

    private static var sheet: some View {
        SheetView(states: [
            Status(enabled: true, batteryThreshold: 20, sensors: sensors(percent: 84, onBattery: true)),
            Status(enabled: false, batteryThreshold: 20, sensors: sensors(percent: 100, onBattery: false)),
            Status(
                enabled: false, batteryThreshold: 20, stopReason: .battery,
                sensors: sensors(percent: 20, onBattery: true)),
            nil,
        ])
    }

    private static func sensors(percent: Int, onBattery: Bool) -> Sensors {
        Sensors(
            lidClosed: false, onBattery: onBattery, batteryPercent: percent,
            batteryTemperature: 31, thermalPressureHigh: false)
    }

    private static func write(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}

private struct SheetView: View {
    @Environment(\.colorScheme) private var scheme
    let states: [Status?]

    var body: some View {
        let dark = scheme == .dark
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 28) {
                ForEach([true, false], id: \.self) { open in
                    Image(nsImage: EyeIcon.image(open: open, width: 64))
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                }
                ForEach([true, false], id: \.self) { open in
                    Image(nsImage: EyeIcon.image(open: open, width: 20))
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                }
            }
            HStack(alignment: .top, spacing: 20) {
                ForEach(states.indices, id: \.self) { index in
                    PanelView(status: states[index], setEnabled: { _ in }, setBatteryThreshold: { _ in })
                        .background(
                            Color(white: dark ? 0.17 : 0.97),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(28)
        .background(Color(white: dark ? 0.08 : 0.86))
        .foregroundStyle(dark ? Color.white : Color.black)
    }
}

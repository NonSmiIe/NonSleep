import AppKit

/// The NonSleep mark: an open eye while the Mac stays awake, a closed one with lashes
/// while it may sleep. A template image, so the menu bar tints it.
enum EyeIcon {
    static func image(open: Bool, width: CGFloat) -> NSImage {
        let size = NSSize(width: width, height: (width * 0.8).rounded())
        let image = NSImage(size: size, flipped: true) { rect in
            let w = rect.width, h = rect.height
            let line = w * 0.085
            NSColor.black.set()
            if open {
                let left = NSPoint(x: line, y: h * 0.5), right = NSPoint(x: w - line, y: h * 0.5)
                let outline = NSBezierPath()
                outline.move(to: left)
                outline.curve(
                    to: right,
                    controlPoint1: NSPoint(x: w * 0.3, y: h * 0.02),
                    controlPoint2: NSPoint(x: w * 0.7, y: h * 0.02))
                outline.curve(
                    to: left,
                    controlPoint1: NSPoint(x: w * 0.7, y: h * 0.98),
                    controlPoint2: NSPoint(x: w * 0.3, y: h * 0.98))
                outline.close()
                stroke(outline, width: line)

                let radius = h * 0.23
                NSBezierPath(ovalIn: NSRect(
                    x: w / 2 - radius, y: h / 2 - radius, width: radius * 2, height: radius * 2)).fill()
                // A glint in the pupil, cut out of the template.
                NSGraphicsContext.current?.compositingOperation = .clear
                let glint = radius * 0.7
                NSBezierPath(ovalIn: NSRect(
                    x: w / 2 + radius * 0.05, y: h / 2 - radius * 0.75, width: glint, height: glint)).fill()
            } else {
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: line, y: h * 0.42))
                lid.curve(
                    to: NSPoint(x: w - line, y: h * 0.42),
                    controlPoint1: NSPoint(x: w * 0.3, y: h * 0.85),
                    controlPoint2: NSPoint(x: w * 0.7, y: h * 0.85))
                stroke(lid, width: line)

                let lashes = NSBezierPath()
                lashes.move(to: NSPoint(x: w * 0.5, y: h * 0.74))
                lashes.line(to: NSPoint(x: w * 0.5, y: h * 0.97))
                lashes.move(to: NSPoint(x: w * 0.275, y: h * 0.66))
                lashes.line(to: NSPoint(x: w * 0.19, y: h * 0.88))
                lashes.move(to: NSPoint(x: w * 0.725, y: h * 0.66))
                lashes.line(to: NSPoint(x: w * 0.81, y: h * 0.88))
                stroke(lashes, width: line)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func stroke(_ path: NSBezierPath, width: CGFloat) {
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}

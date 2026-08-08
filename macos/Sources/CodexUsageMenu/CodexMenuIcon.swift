import AppKit

enum CodexMenuIcon {
    static func make() -> NSImage {
        let canvas = NSSize(width: 18, height: 18)
        let image = NSImage(size: canvas, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current else { return false }

            context.saveGraphicsState()
            context.shouldAntialias = true
            NSColor.black.setFill()
            NSColor.black.setStroke()

            let gauge = NSBezierPath()
            gauge.lineCapStyle = .round
            gauge.lineWidth = 1.7
            gauge.appendArc(
                withCenter: NSPoint(x: bounds.midX, y: 7.65),
                radius: 6.8,
                startAngle: 180,
                endAngle: 0,
                clockwise: true
            )
            gauge.stroke()

            let ticks = NSBezierPath()
            ticks.lineCapStyle = .round
            ticks.lineWidth = 1.15
            ticks.move(to: NSPoint(x: 4.15, y: 11.95))
            ticks.line(to: NSPoint(x: 5, y: 11.55))
            ticks.move(to: NSPoint(x: 9, y: 14.45))
            ticks.line(to: NSPoint(x: 9, y: 13.5))
            ticks.move(to: NSPoint(x: 13.85, y: 11.95))
            ticks.line(to: NSPoint(x: 13, y: 11.55))
            ticks.stroke()

            let needle = NSBezierPath()
            needle.lineCapStyle = .round
            needle.lineWidth = 1.35
            needle.move(to: NSPoint(x: 9, y: 8.6))
            needle.line(to: NSPoint(x: 13.2, y: 11.55))
            needle.stroke()
            NSBezierPath(ovalIn: NSRect(x: 8.25, y: 7.85, width: 1.5, height: 1.5)).fill()

            let center = NSPoint(x: bounds.midX, y: 8.6)
            let lobeRadius: CGFloat = 1.95
            let orbitRadius: CGFloat = 2.15

            for index in 0..<6 {
                let angle = CGFloat(index) * (.pi * 2 / 6) + (.pi / 2)
                let lobeCenter = NSPoint(
                    x: center.x + cos(angle) * orbitRadius,
                    y: center.y + sin(angle) * orbitRadius
                )

                NSBezierPath(
                    ovalIn: NSRect(
                        x: lobeCenter.x - lobeRadius,
                        y: lobeCenter.y - lobeRadius,
                        width: lobeRadius * 2,
                        height: lobeRadius * 2
                    )
                ).fill()
            }

            NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - 2.4,
                    y: center.y - 2.4,
                    width: 4.8,
                    height: 4.8
                )
            ).fill()

            context.compositingOperation = .clear
            let glyph = NSBezierPath()
            glyph.lineCapStyle = .round
            glyph.lineJoinStyle = .round
            glyph.lineWidth = 0.9

            glyph.move(to: NSPoint(x: 6.9, y: 10.15))
            glyph.line(to: NSPoint(x: 8.05, y: 8.6))
            glyph.line(to: NSPoint(x: 6.9, y: 7.05))
            glyph.stroke()

            let underscore = NSBezierPath()
            underscore.lineCapStyle = .round
            underscore.lineWidth = 0.9
            underscore.move(to: NSPoint(x: 10, y: 7.1))
            underscore.line(to: NSPoint(x: 12.15, y: 7.1))
            underscore.stroke()

            context.restoreGraphicsState()
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "Codex usage meter"
        return image
    }
}

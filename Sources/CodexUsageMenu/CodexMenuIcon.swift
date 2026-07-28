import AppKit

enum CodexMenuIcon {
    static func make() -> NSImage {
        let canvas = NSSize(width: 18, height: 18)
        let image = NSImage(size: canvas, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current else { return false }

            context.saveGraphicsState()
            NSColor.black.setFill()

            let center = NSPoint(x: bounds.midX, y: bounds.midY)
            let lobeRadius: CGFloat = 3.55
            let orbitRadius: CGFloat = 3.85

            for index in 0..<7 {
                let angle = CGFloat(index) * (.pi * 2 / 7) + (.pi / 2)
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
                    x: center.x - 4.5,
                    y: center.y - 4.5,
                    width: 9,
                    height: 9
                )
            ).fill()

            context.compositingOperation = .clear
            let glyph = NSBezierPath()
            glyph.lineCapStyle = .round
            glyph.lineJoinStyle = .round
            glyph.lineWidth = 1.55

            glyph.move(to: NSPoint(x: 5.25, y: 11.8))
            glyph.line(to: NSPoint(x: 7.2, y: 9))
            glyph.line(to: NSPoint(x: 5.25, y: 6.2))
            glyph.stroke()

            let underscore = NSBezierPath()
            underscore.lineCapStyle = .round
            underscore.lineWidth = 1.55
            underscore.move(to: NSPoint(x: 9.7, y: 6.35))
            underscore.line(to: NSPoint(x: 13.2, y: 6.35))
            underscore.stroke()

            context.restoreGraphicsState()
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "Codex"
        return image
    }
}

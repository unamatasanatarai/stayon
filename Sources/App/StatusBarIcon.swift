import Cocoa

public enum StatusBarIcon {
    public static let iconSize = NSSize(width: 18, height: 18)

    public static var uncheckedCheckboxImage: NSImage {
        let size = NSSize(width: 13, height: 13)
        let image = NSImage(size: size, flipped: false) { rect in
            let boxRect = NSRect(x: 1.0, y: 1.0, width: 11.0, height: 11.0)
            let path = NSBezierPath(roundedRect: boxRect, xRadius: 2.5, yRadius: 2.5)
            NSColor.black.setStroke()
            path.lineWidth = 1.2
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    public static var checkedCheckboxImage: NSImage {
        let size = NSSize(width: 13, height: 13)
        let image = NSImage(size: size, flipped: false) { rect in
            let boxRect = NSRect(x: 1.0, y: 1.0, width: 11.0, height: 11.0)
            let path = NSBezierPath(roundedRect: boxRect, xRadius: 2.5, yRadius: 2.5)
            NSColor.black.setStroke()
            path.lineWidth = 1.2
            path.stroke()

            let check = NSBezierPath()
            check.move(to: NSPoint(x: 3.5, y: 6.5))
            check.line(to: NSPoint(x: 5.5, y: 4.0))
            check.line(to: NSPoint(x: 9.5, y: 9.0))
            check.lineWidth = 1.4
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.black.setStroke()
            check.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    @MainActor
    public static func image(isActive: Bool, isDark: Bool? = nil) -> NSImage {
        // Resolve the appearance here on the main actor; the drawing handler is
        // not actor-isolated and must not touch NSApp.
        let dark = isDark ?? (NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let image = NSImage(size: iconSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawIcon(in: rect, ctx: ctx, isActive: isActive, isDark: dark)
            return true
        }
        // Template image enables native macOS appearance tinting, selection highlighting,
        // and automatic light/dark vibrancy transitions
        image.isTemplate = (isDark == nil)
        return image
    }

    public static let iconWhiteColor = NSColor(srgbRed: 0xe9 / 255.0, green: 0xe9 / 255.0, blue: 0xe9 / 255.0, alpha: 1.0)
    public static let iconBlackColor = NSColor(srgbRed: 0x20 / 255.0, green: 0x20 / 255.0, blue: 0x20 / 255.0, alpha: 1.0)

    private static func drawIcon(in rect: NSRect, ctx: CGContext, isActive: Bool, isDark: Bool) {
        // User specification:
        // Light mode: dark (#202020) background with white (#e9e9e9) line
        // Dark mode: light (#e9e9e9) background with dark (#202020) line
        let bgColor = isDark ? iconWhiteColor : iconBlackColor
        let lineColor = isDark ? iconBlackColor : iconWhiteColor

        let badgeMargin: CGFloat = 1.0
        let badgeRect = CGRect(
            x: badgeMargin,
            y: badgeMargin,
            width: rect.width - 2 * badgeMargin,
            height: rect.height - 2 * badgeMargin
        )
        let cornerRadius: CGFloat = 3.5

        let badgePath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        ctx.addPath(badgePath)
        ctx.setFillColor(bgColor.cgColor)
        ctx.fillPath()

        if isDark {
            ctx.addPath(badgePath)
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.0, alpha: 0.22).cgColor)
            ctx.setLineWidth(0.6)
            ctx.strokePath()
        }

        let graphicWidth = badgeRect.width - 2.5
        let graphicHeight: CGFloat = 8.5
        let gx = badgeRect.midX - graphicWidth / 2.0
        let gy = badgeRect.midY - graphicHeight / 2.0
        let graphicRect = CGRect(x: gx, y: gy, width: graphicWidth, height: graphicHeight)

        let graphicPath: CGPath
        if isActive {
            graphicPath = makePulseOnPath(targetRect: graphicRect)
        } else {
            let offRect = CGRect(x: gx, y: badgeRect.midY - 0.5, width: graphicWidth, height: 1.0)
            graphicPath = makePulseOffPath(targetRect: offRect)
        }

        ctx.addPath(graphicPath)
        ctx.setStrokeColor(lineColor.cgColor)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }

    private static func makePulseOnPath(targetRect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let svgWidth: CGFloat = 480
        let svgHeight: CGFloat = 234
        let scaleX = targetRect.width / svgWidth
        let scaleY = targetRect.height / svgHeight

        let dx: CGFloat = -16
        let dy: CGFloat = -43

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let px = (x + dx) * scaleX + targetRect.minX
            let py = targetRect.minY + (svgHeight - (y + dy)) * scaleY
            return CGPoint(x: px, y: py)
        }

        path.move(to: pt(28, 160))
        path.addLine(to: pt(76, 160))
        path.addCurve(to: pt(128, 213), control1: pt(96, 160), control2: pt(103, 213))
        path.addCurve(to: pt(211, 55), control1: pt(155, 213), control2: pt(173, 55))
        path.addCurve(to: pt(292, 265), control1: pt(248, 55), control2: pt(264, 265))
        path.addCurve(to: pt(366, 122), control1: pt(319, 265), control2: pt(330, 122))
        path.addCurve(to: pt(429, 181), control1: pt(394, 122), control2: pt(400, 181))
        path.addLine(to: pt(484, 181))
        return path
    }

    private static func makePulseOffPath(targetRect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let scaleX = targetRect.width / 480.0
        let scaleY = targetRect.height / 24.0

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let px = x * scaleX + targetRect.minX
            let py = targetRect.minY + (24.0 - y) * scaleY
            return CGPoint(x: px, y: py)
        }

        path.move(to: pt(12, 12))
        path.addLine(to: pt(468, 12))
        return path
    }
}

#!/usr/bin/env swift
import Cocoa

func makePulseOnPath(targetRect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let svgWidth: CGFloat = 480
    let svgHeight: CGFloat = 234
    let scaleX = targetRect.width / svgWidth
    let scaleY = targetRect.height / svgHeight

    let dx: CGFloat = -16
    let dy: CGFloat = -43

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let px = (x + dx) * scaleX + targetRect.minX
        let py = targetRect.maxY - (y + dy) * scaleY
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

func makePulseOffPath(targetRect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let svgWidth: CGFloat = 480
    let svgHeight: CGFloat = 24
    let scaleX = targetRect.width / svgWidth
    let scaleY = targetRect.height / svgHeight

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let px = x * scaleX + targetRect.minX
        let py = targetRect.maxY - y * scaleY
        return CGPoint(x: px, y: py)
    }

    path.move(to: pt(12, 12))
    path.addLine(to: pt(468, 12))
    return path
}

func renderStatusBarBitmap(size: CGFloat, isActive: Bool, isDark: Bool) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = size / 18.0
    ctx.scaleBy(x: scale, y: scale)

    // User specification:
    // Light mode: dark background, white line
    // Dark mode: light background, dark line
    let bgColor = isDark ? NSColor.white : NSColor.black
    let lineColor = isDark ? NSColor.black : NSColor.white

    let badgeMargin: CGFloat = 1.0
    let badgeRect = CGRect(x: badgeMargin, y: badgeMargin, width: 18.0 - 2 * badgeMargin, height: 18.0 - 2 * badgeMargin)
    let cornerRadius: CGFloat = 3.5

    let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.addPath(badgePath)
    ctx.setFillColor(bgColor.cgColor)
    ctx.fillPath()

    // Subtle outer stroke for light background (Dark Mode) against dark/gray menu bar
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

    return rep
}

func generateAll() {
    let scriptUrl = URL(fileURLWithPath: CommandLine.arguments[0])
    let repoRoot = scriptUrl.deletingLastPathComponent().deletingLastPathComponent()
    let resourcesDir = repoRoot.appendingPathComponent("Resources")

    let configs: [(String, Bool, Bool)] = [
        ("StatusBarIcon_Active_Dark", true, true),
        ("StatusBarIcon_Active_Light", true, false),
        ("StatusBarIcon_Inactive_Dark", false, true),
        ("StatusBarIcon_Inactive_Light", false, false)
    ]

    for (name, isActive, isDark) in configs {
        let rep1x = renderStatusBarBitmap(size: 18, isActive: isActive, isDark: isDark)
        let rep2x = renderStatusBarBitmap(size: 36, isActive: isActive, isDark: isDark)

        let data1x = rep1x.representation(using: .png, properties: [:])!
        let data2x = rep2x.representation(using: .png, properties: [:])!

        try! data1x.write(to: resourcesDir.appendingPathComponent("\(name).png"))
        try! data2x.write(to: resourcesDir.appendingPathComponent("\(name)@2x.png"))
        print("✅ Generated \(name).png (18x18 and 36x36)")
    }

    // Default status bar icons (active state)
    let actDark1x = renderStatusBarBitmap(size: 18, isActive: true, isDark: true)
    let actDark2x = renderStatusBarBitmap(size: 36, isActive: true, isDark: true)
    let actLight1x = renderStatusBarBitmap(size: 18, isActive: true, isDark: false)
    let actLight2x = renderStatusBarBitmap(size: 36, isActive: true, isDark: false)

    try! actDark1x.representation(using: .png, properties: [:])!.write(to: resourcesDir.appendingPathComponent("StatusBarIcon_Dark.png"))
    try! actDark2x.representation(using: .png, properties: [:])!.write(to: resourcesDir.appendingPathComponent("StatusBarIcon_Dark@2x.png"))
    try! actLight1x.representation(using: .png, properties: [:])!.write(to: resourcesDir.appendingPathComponent("StatusBarIcon_Light.png"))
    try! actLight2x.representation(using: .png, properties: [:])!.write(to: resourcesDir.appendingPathComponent("StatusBarIcon_Light@2x.png"))
    try! actDark1x.representation(using: .png, properties: [:])!.write(to: resourcesDir.appendingPathComponent("StatusBarIcon.png"))
    try! actDark2x.representation(using: .png, properties: [:])!.write(to: resourcesDir.appendingPathComponent("StatusBarIcon@2x.png"))

    print("🎉 All status bar icons generated successfully!")
}

generateAll()

#!/usr/bin/env swift
import Cocoa

func parsePath(d: String, tx: CGFloat, ty: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let tokens = d.replacingOccurrences(of: ",", with: " ")
                  .components(separatedBy: .whitespacesAndNewlines)
                  .filter { !$0.isEmpty }

    var idx = 0
    var currentCmd = ""

    while idx < tokens.count {
        let token = tokens[idx]
        if let firstChar = token.first, firstChar.isLetter {
            currentCmd = token
            idx += 1
            continue
        }

        switch currentCmd {
        case "M":
            let x = CGFloat(Double(tokens[idx]) ?? 0) + tx
            let y = CGFloat(Double(tokens[idx + 1]) ?? 0) + ty
            path.move(to: CGPoint(x: x, y: y))
            idx += 2
        case "L":
            let x = CGFloat(Double(tokens[idx]) ?? 0) + tx
            let y = CGFloat(Double(tokens[idx + 1]) ?? 0) + ty
            path.addLine(to: CGPoint(x: x, y: y))
            idx += 2
        case "C":
            let c1x = CGFloat(Double(tokens[idx]) ?? 0) + tx
            let c1y = CGFloat(Double(tokens[idx + 1]) ?? 0) + ty
            let c2x = CGFloat(Double(tokens[idx + 2]) ?? 0) + tx
            let c2y = CGFloat(Double(tokens[idx + 3]) ?? 0) + ty
            let ex  = CGFloat(Double(tokens[idx + 4]) ?? 0) + tx
            let ey  = CGFloat(Double(tokens[idx + 5]) ?? 0) + ty
            path.addCurve(to: CGPoint(x: ex, y: ey), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
            idx += 6
        default:
            idx += 1
        }
    }
    return path
}

func parseColor(hex: String) -> NSColor {
    var hexClean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if hexClean.hasPrefix("#") {
        hexClean.removeFirst()
    }
    if hexClean.count == 3 {
        let r = hexClean.prefix(1)
        let g = hexClean.dropFirst().prefix(1)
        let b = hexClean.suffix(1)
        hexClean = "\(r)\(r)\(g)\(g)\(b)\(b)"
    }
    if hexClean.count == 6, let intVal = UInt32(hexClean, radix: 16) {
        let red = CGFloat((intVal >> 16) & 0xFF) / 255.0
        let green = CGFloat((intVal >> 8) & 0xFF) / 255.0
        let blue = CGFloat(intVal & 0xFF) / 255.0
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }
    return .black
}

func color(hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha)
}

func generateAppIcons() {
    let scriptUrl = URL(fileURLWithPath: CommandLine.arguments[0])
    let repoRoot = scriptUrl.deletingLastPathComponent().deletingLastPathComponent()
    let resourcesDir = repoRoot.appendingPathComponent("Resources")

    let bkgUrl = resourcesDir.appendingPathComponent("pulse-appicon-bkg.png")
    let svgUrl = resourcesDir.appendingPathComponent("pulse-on.svg")

    guard let bkgImage = NSImage(contentsOf: bkgUrl) else {
        fatalError("Error: Could not load \(bkgUrl.path)")
    }
    guard let svgString = try? String(contentsOf: svgUrl, encoding: .utf8) else {
        fatalError("Error: Could not read \(svgUrl.path)")
    }

    // Parse SVG attributes
    guard let dStart = svgString.range(of: "d=\"")?.upperBound,
          let dEnd = svgString[dStart...].range(of: "\"")?.lowerBound else {
        fatalError("Error: Could not parse path d attribute in \(svgUrl.path)")
    }
    let dAttr = String(svgString[dStart..<dEnd])

    var tx: CGFloat = 0
    var ty: CGFloat = 0
    if let transRange = svgString.range(of: "translate(") {
        let tStart = transRange.upperBound
        if let tEnd = svgString[tStart...].range(of: ")")?.lowerBound {
            let parts = svgString[tStart..<tEnd].replacingOccurrences(of: ",", with: " ")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            if parts.count >= 2 {
                tx = CGFloat(Double(parts[0]) ?? 0)
                ty = CGFloat(Double(parts[1]) ?? 0)
            }
        }
    }

    var customStrokeColor: NSColor? = nil
    if CommandLine.arguments.contains("--white") {
        customStrokeColor = .white
    } else if let colorIdx = CommandLine.arguments.firstIndex(of: "--color"), colorIdx + 1 < CommandLine.arguments.count {
        customStrokeColor = parseColor(hex: CommandLine.arguments[colorIdx + 1])
    }

    let pulsePath = parsePath(d: dAttr, tx: tx, ty: ty)
    let masterSize: CGFloat = 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // -------------------------------------------------------------
    // 1. Render Supreme Background (Obsidian Glass + Radiant Glow)
    // -------------------------------------------------------------
    let bkgRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(masterSize),
        pixelsHigh: Int(masterSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let bkgCtx = NSGraphicsContext(bitmapImageRep: bkgRep)!.cgContext

    // Draw original base squircle for shadow & continuous curvature
    if let cgBkg = bkgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        bkgCtx.draw(cgBkg, in: CGRect(x: 0, y: 0, width: masterSize, height: masterSize))
    }

    // Paint deep obsidian glass within squircle mask
    bkgCtx.saveGState()
    bkgCtx.setBlendMode(.sourceIn)

    let bgColors = [
        color(hex: 0x161A26).cgColor,  // Top: sleek deep slate
        color(hex: 0x0D1018).cgColor,  // Mid: deep obsidian glass
        color(hex: 0x05060A).cgColor   // Bottom: midnight void
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.45, 1.0]) {
        bkgCtx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: masterSize), end: CGPoint(x: 0, y: 0), options: [])
    }

    bkgCtx.setBlendMode(.sourceAtop)

    // Ambient cyan/blue awake glow radiating from the center pulse
    let auraColors = [
        color(hex: 0x00E5FF, alpha: 0.30).cgColor,
        color(hex: 0x0066FF, alpha: 0.16).cgColor,
        color(hex: 0x000000, alpha: 0.0).cgColor
    ] as CFArray
    if let auraGrad = CGGradient(colorsSpace: colorSpace, colors: auraColors, locations: [0.0, 0.32, 1.0]) {
        bkgCtx.drawRadialGradient(auraGrad, startCenter: CGPoint(x: 512, y: 512), startRadius: 0, endCenter: CGPoint(x: 512, y: 512), endRadius: 440, options: [])
    }

    // Subtle concentric vital-sign resonance rings
    for r in [160.0, 240.0, 320.0, 400.0] {
        bkgCtx.saveGState()
        bkgCtx.setLineWidth(1.5)
        bkgCtx.setStrokeColor(color(hex: 0x00E5FF, alpha: 0.055).cgColor)
        bkgCtx.strokeEllipse(in: CGRect(x: 512 - r, y: 512 - r, width: r * 2, height: r * 2))
        bkgCtx.restoreGState()
    }

    // Top Rim Catch-Light (Apple glass reflection)
    let rimColors = [
        color(hex: 0xFFFFFF, alpha: 0.32).cgColor,
        color(hex: 0xFFFFFF, alpha: 0.06).cgColor,
        color(hex: 0xFFFFFF, alpha: 0.0).cgColor
    ] as CFArray
    if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.07, 0.20]) {
        bkgCtx.drawLinearGradient(rimGrad, start: CGPoint(x: 0, y: masterSize), end: CGPoint(x: 0, y: 0), options: [])
    }

    // Bottom subtle ambient bounce reflection
    let bounceColors = [
        color(hex: 0xFFFFFF, alpha: 0.0).cgColor,
        color(hex: 0xFFFFFF, alpha: 0.04).cgColor,
        color(hex: 0xFFFFFF, alpha: 0.08).cgColor
    ] as CFArray
    if let bounceGrad = CGGradient(colorsSpace: colorSpace, colors: bounceColors, locations: [0.0, 0.93, 1.0]) {
        bkgCtx.drawLinearGradient(bounceGrad, start: CGPoint(x: 0, y: masterSize), end: CGPoint(x: 0, y: 0), options: [])
    }

    bkgCtx.restoreGState()

    // Save updated 512x512 pulse-appicon-bkg.png
    let bkg512 = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 512,
        pixelsHigh: 512,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let ctxBkg512 = NSGraphicsContext(bitmapImageRep: bkg512)!.cgContext
    ctxBkg512.interpolationQuality = .high
    if let bkgCG = bkgRep.cgImage {
        ctxBkg512.draw(bkgCG, in: CGRect(x: 0, y: 0, width: 512, height: 512))
    }
    if let bkg512Data = bkg512.representation(using: .png, properties: [:]) {
        try? bkg512Data.write(to: bkgUrl)
        print("✅ Updated \(bkgUrl.path) (512x512)")
    }

    // -------------------------------------------------------------
    // 2. Render Master Icon (Background + Supreme Pulse Line)
    // -------------------------------------------------------------
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(masterSize),
        pixelsHigh: Int(masterSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext

    // Draw the supreme background
    if let bkgCG = bkgRep.cgImage {
        ctx.draw(bkgCG, in: CGRect(x: 0, y: 0, width: masterSize, height: masterSize))
    }

    // Pulse Path geometry
    let targetWidth: CGFloat = 660
    let scale = targetWidth / 480.0
    let targetHeight = 234.0 * scale
    let originX = (masterSize - targetWidth) / 2
    let originY = (masterSize - targetHeight) / 2
    let strokeWidth: CGFloat = 26.0

    ctx.saveGState()
    ctx.translateBy(x: originX, y: originY + targetHeight)
    ctx.scaleBy(x: scale, y: -scale) // Flip Y to match SVG coordinate system

    if let custom = customStrokeColor {
        // Custom single-color override
        ctx.addPath(pulsePath)
        ctx.setStrokeColor(custom.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    } else {
        // Supreme multi-pass electric neon rendering
        let lineColors = [
            color(hex: 0x00E5FF).cgColor,  // Vivid Electric Cyan
            color(hex: 0x0099FF).cgColor,  // Radiant Aqua-Azure
            color(hex: 0x007AFF).cgColor   // Apple Electric Blue
        ]
        let glowColor = color(hex: 0x00D2FF, alpha: 0.75)

        // Pass 1: Soft Contact Drop Shadow (3D float effect)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 18, color: color(hex: 0x000000, alpha: 0.70).cgColor)
        ctx.addPath(pulsePath)
        ctx.setStrokeColor(color(hex: 0x000000, alpha: 0.50).cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()

        // Pass 2: Wide Ambient Neon Bloom
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 36, color: glowColor.cgColor)
        ctx.addPath(pulsePath)
        ctx.setStrokeColor(glowColor.withAlphaComponent(0.40).cgColor)
        ctx.setLineWidth(strokeWidth + 8)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()

        // Pass 3: Intense Near Bloom + Radiant Core Gradient
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 12, color: glowColor.cgColor)
        ctx.addPath(pulsePath)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        if let grad = CGGradient(colorsSpace: colorSpace, colors: lineColors as CFArray, locations: [0.0, 0.5, 1.0]) {
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 120), end: CGPoint(x: 480, y: 120), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.restoreGState()

        // Pass 4: Inner Core Filament (soft luminous white tube highlight)
        ctx.saveGState()
        ctx.addPath(pulsePath)
        ctx.setLineWidth(strokeWidth * 0.28)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let coreColors = [
            color(hex: 0xFFFFFF, alpha: 0.60).cgColor,
            color(hex: 0xFFFFFF, alpha: 0.95).cgColor,
            color(hex: 0xFFFFFF, alpha: 0.60).cgColor
        ] as CFArray
        if let coreGrad = CGGradient(colorsSpace: colorSpace, colors: coreColors, locations: [0.0, 0.5, 1.0]) {
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            ctx.drawLinearGradient(coreGrad, start: CGPoint(x: 0, y: 120), end: CGPoint(x: 480, y: 120), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.restoreGState()
    }

    ctx.restoreGState()

    guard rep.representation(using: .png, properties: [:]) != nil else {
        fatalError("Error: Failed to encode master PNG")
    }

    // Save 512x512 AppIcon.png
    let appIconPngUrl = resourcesDir.appendingPathComponent("AppIcon.png")
    let appIcon512 = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 512,
        pixelsHigh: 512,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let ctx512 = NSGraphicsContext(bitmapImageRep: appIcon512)!.cgContext
    ctx512.interpolationQuality = .high
    if let masterCG = rep.cgImage {
        ctx512.draw(masterCG, in: CGRect(x: 0, y: 0, width: 512, height: 512))
    }
    let png512Data = appIcon512.representation(using: .png, properties: [:])!
    try! png512Data.write(to: appIconPngUrl)
    print("✅ Created \(appIconPngUrl.path) (512x512)")

    // Generate .iconset for iconutil
    let iconsetDir = URL(fileURLWithPath: "/tmp/StayOn_AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconsetDir)
    try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

    let sizes: [(Int, String)] = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]

    for (px, name) in sizes {
        let sizeRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px,
            pixelsHigh: px,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let sizeCtx = NSGraphicsContext(bitmapImageRep: sizeRep)!.cgContext
        sizeCtx.interpolationQuality = .high
        if let masterCG = rep.cgImage {
            sizeCtx.draw(masterCG, in: CGRect(x: 0, y: 0, width: px, height: px))
        }
        let fileData = sizeRep.representation(using: .png, properties: [:])!
        try! fileData.write(to: iconsetDir.appendingPathComponent(name))
    }

    let icnsUrl = resourcesDir.appendingPathComponent("AppIcon.icns")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsUrl.path]
    try! proc.run()
    proc.waitUntilExit()

    try? FileManager.default.removeItem(at: iconsetDir)
    print("✅ Created \(icnsUrl.path) via iconutil")
}

generateAppIcons()

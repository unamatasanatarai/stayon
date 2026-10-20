#!/usr/bin/env swift
import Cocoa

// MARK: - Dimensions & Coordinates
let width: CGFloat = 660
let height: CGFloat = 400

// Finder icon coordinates in points (top-left origin)
let stayOnCenter = CGPoint(x: 180, y: 200)
let appsCenter = CGPoint(x: 480, y: 200)

// Helper: Color from Hex
func color(hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha)
}

// Exact StayOn pulse waveform scaled and centered
func makeStayOnPulsePath(centerX: CGFloat, baselineY: CGFloat, pulseWidth: CGFloat, pulseHeight: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let origWidth: CGFloat = 353.0
    let origHeight: CGFloat = 210.0
    let scaleX = pulseWidth / origWidth
    let scaleY = pulseHeight / origHeight
    let startX = centerX - (pulseWidth / 2.0)
    
    func mapPoint(_ sx: CGFloat, _ sy: CGFloat) -> CGPoint {
        let px = startX + (sx - 76.0) * scaleX
        let py = baselineY + (sy - 160.0) * scaleY
        return CGPoint(x: px, y: py)
    }
    
    path.move(to: mapPoint(76, 160))
    path.addCurve(to: mapPoint(128, 213), control1: mapPoint(96, 160), control2: mapPoint(103, 213))
    path.addCurve(to: mapPoint(211, 55), control1: mapPoint(155, 213), control2: mapPoint(173, 55))
    path.addCurve(to: mapPoint(292, 265), control1: mapPoint(248, 55), control2: mapPoint(264, 265))
    path.addCurve(to: mapPoint(366, 122), control1: mapPoint(319, 265), control2: mapPoint(330, 122))
    path.addCurve(to: mapPoint(429, 181), control1: mapPoint(394, 122), control2: mapPoint(400, 181))
    path.addLine(to: mapPoint(438, 160))
    return path
}

// MARK: - Main Render Function
func renderDMGBackground(scale: CGFloat, includeMockIcons: Bool = false) -> NSBitmapImageRep {
    let pixelWidth = Int(width * scale)
    let pixelHeight = Int(height * scale)
    
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create graphics context")
    }
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext
    
    // Scale for Retina
    ctx.scaleBy(x: scale, y: scale)
    
    // Flip coordinate system so (0,0) is TOP-LEFT (matching Finder)
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1.0, y: -1.0)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // -------------------------------------------------------------
    // 1. Sleek Bright Light Base Gradient
    // -------------------------------------------------------------
    // Soft, luminous studio lighting: pure white top fading to crisp light silver-slate
    let bgColors = [
        color(hex: 0xFFFFFF).cgColor,
        color(hex: 0xF7F9FB).cgColor,
        color(hex: 0xEBEEF3).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.45, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])
    }
    
    // Ambient awake radiance: delicate radial energy aura
    let auraColors = [
        color(hex: 0x007AFF, alpha: 0.045).cgColor,
        color(hex: 0x34C759, alpha: 0.020).cgColor,
        color(hex: 0xFFFFFF, alpha: 0.0).cgColor
    ] as CFArray
    if let auraGradient = CGGradient(colorsSpace: colorSpace, colors: auraColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(
            auraGradient,
            startCenter: CGPoint(x: 330, y: 195),
            startRadius: 0,
            endCenter: CGPoint(x: 330, y: 195),
            endRadius: 270,
            options: []
        )
    }

    // -------------------------------------------------------------
    // 2. Subtle Inset & Hairline Studio Dividers
    // -------------------------------------------------------------
    // Outer frame hairline
    ctx.saveGState()
    ctx.setLineWidth(1.0)
    ctx.setStrokeColor(color(hex: 0x000000, alpha: 0.065).cgColor)
    ctx.stroke(CGRect(x: 0.5, y: 0.5, width: width - 1.0, height: height - 1.0))
    ctx.restoreGState()
    
    // Gradient-faded dividers
    let dividerColors = [
        color(hex: 0x000000, alpha: 0.0).cgColor,
        color(hex: 0x000000, alpha: 0.065).cgColor,
        color(hex: 0x000000, alpha: 0.0).cgColor
    ] as CFArray
    if let divGrad = CGGradient(colorsSpace: colorSpace, colors: dividerColors, locations: [0.0, 0.5, 1.0]) {
        // Top divider at Finder y = 98
        ctx.saveGState()
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: 48, y: 98))
        ctx.addLine(to: CGPoint(x: width - 48, y: 98))
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(divGrad, start: CGPoint(x: 48, y: 98), end: CGPoint(x: width - 48, y: 98), options: [])
        ctx.restoreGState()
        
        // Bottom divider at Finder y = 328
        ctx.saveGState()
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: 48, y: 328))
        ctx.addLine(to: CGPoint(x: width - 48, y: 328))
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(divGrad, start: CGPoint(x: 48, y: 328), end: CGPoint(x: width - 48, y: 328), options: [])
        ctx.restoreGState()
    }

    // -------------------------------------------------------------
    // 3. Frosted Icon Pedestals (Dock Landing Pads)
    // -------------------------------------------------------------
    func drawPedestal(at center: CGPoint) {
        let size: CGFloat = 118
        let rect = CGRect(x: center.x - size / 2.0, y: center.y - size / 2.0, width: size, height: size)
        let radius: CGFloat = 26
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        
        ctx.saveGState()
        // Soft tactile drop shadow
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 14, color: color(hex: 0x000000, alpha: 0.05).cgColor)
        
        let pedGrad = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                color(hex: 0xFFFFFF, alpha: 0.90).cgColor,
                color(hex: 0xF5F7FA, alpha: 0.65).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(pedGrad, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.minX, y: rect.maxY), options: [])
        ctx.restoreGState()
        
        // Outer crisp hairline border
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(color(hex: 0x000000, alpha: 0.06).cgColor)
        ctx.strokePath()
        
        // Inner luminous highlight rim
        let innerRect = rect.insetBy(dx: 1.0, dy: 1.0)
        let innerPath = CGPath(roundedRect: innerRect, cornerWidth: radius - 1, cornerHeight: radius - 1, transform: nil)
        ctx.addPath(innerPath)
        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(color(hex: 0xFFFFFF, alpha: 0.95).cgColor)
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    drawPedestal(at: stayOnCenter)
    drawPedestal(at: appsCenter)

    // -------------------------------------------------------------
    // 4. Sleek Pulse Wave Arrow (The Heartbeat of StayOn)
    // -------------------------------------------------------------
    let centerY: CGFloat = 196
    let arrowStartX: CGFloat = 248
    let arrowEndX: CGFloat = 412
    let pulseCenterX: CGFloat = 330
    let pulseWidth: CGFloat = 82
    let pulseHeight: CGFloat = 44
    
    // Delicate dotted baseline guide track (vital signs / oscilloscope track)
    ctx.saveGState()
    ctx.setLineWidth(1.5)
    ctx.setLineDash(phase: 0, lengths: [3, 4])
    ctx.setStrokeColor(color(hex: 0x000000, alpha: 0.08).cgColor)
    ctx.move(to: CGPoint(x: arrowStartX, y: centerY))
    ctx.addLine(to: CGPoint(x: arrowEndX - 10, y: centerY))
    ctx.strokePath()
    ctx.restoreGState()

    // Full Pulse Arrow Path
    let pulseStartX = pulseCenterX - (pulseWidth / 2.0)
    let fullArrowPath = CGMutablePath()
    fullArrowPath.move(to: CGPoint(x: arrowStartX, y: centerY))
    fullArrowPath.addLine(to: CGPoint(x: pulseStartX, y: centerY))
    
    let pulseWave = makeStayOnPulsePath(
        centerX: pulseCenterX,
        baselineY: centerY,
        pulseWidth: pulseWidth,
        pulseHeight: pulseHeight
    )
    fullArrowPath.addPath(pulseWave)
    fullArrowPath.addLine(to: CGPoint(x: arrowEndX, y: centerY))

    // Crisp aerodynamic arrowhead
    let headLen: CGFloat = 14.0
    let headSpread: CGFloat = 9.5
    let arrowHead = CGMutablePath()
    arrowHead.move(to: CGPoint(x: arrowEndX - headLen, y: centerY - headSpread))
    arrowHead.addLine(to: CGPoint(x: arrowEndX, y: centerY))
    arrowHead.addLine(to: CGPoint(x: arrowEndX - headLen, y: centerY + headSpread))

    // Stroke Pulse Arrow with energetic gradient + soft glow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: color(hex: 0x007AFF, alpha: 0.28).cgColor)
    ctx.addPath(fullArrowPath)
    ctx.addPath(arrowHead)
    ctx.setLineWidth(3.4)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    
    let arrowGradColors = [
        color(hex: 0x1D2129).cgColor,  // Sleek graphite matching StayOn squircle
        color(hex: 0x0062E3).cgColor,  // Vibrant transition
        color(hex: 0x007AFF).cgColor   // Apple electric blue
    ] as CFArray
    if let strokeGrad = CGGradient(colorsSpace: colorSpace, colors: arrowGradColors, locations: [0.0, 0.55, 1.0]) {
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(strokeGrad, start: CGPoint(x: arrowStartX, y: centerY), end: CGPoint(x: arrowEndX, y: centerY), options: [])
    }
    ctx.restoreGState()

    // -------------------------------------------------------------
    // 5. Typography (SF Pro, High Legibility, Native macOS Layout)
    // -------------------------------------------------------------
    ctx.saveGState()
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1.0, y: -1.0)
    
    func drawCenteredText(
        _ text: String,
        at point: CGPoint,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        kern: CGFloat = 0.0
    ) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: kern
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        let rect = CGRect(x: point.x - size.width / 2.0, y: point.y - size.height / 2.0, width: size.width, height: size.height)
        attrStr.draw(in: rect)
    }

    // Top Header Title: "StayOn"
    // Finder y = 46 -> Cocoa y = 354
    drawCenteredText("StayOn", at: CGPoint(x: width / 2.0, y: 354), fontSize: 24, weight: .bold, color: color(hex: 0x1D1D1F), kern: -0.4)
    
    // Top Subtitle: "Keep your Mac awake when it matters most"
    // Finder y = 72 -> Cocoa y = 328
    drawCenteredText("Keep your Mac awake when it matters most", at: CGPoint(x: width / 2.0, y: 328), fontSize: 12.5, weight: .regular, color: color(hex: 0x6E737D))

    // Instruction Capsule: "Drag to Applications"
    // Finder y = 254 -> Cocoa y = 146
    let pillText = "Drag to Applications"
    let pillFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    let pAttrs: [NSAttributedString.Key: Any] = [
        .font: pillFont,
        .foregroundColor: color(hex: 0x363A42),
        .kern: 0.2
    ]
    let pStr = NSAttributedString(string: pillText, attributes: pAttrs)
    let pSize = pStr.size()
    let pillW = pSize.width + 24
    let pillH: CGFloat = 22
    let pillY: CGFloat = 146
    let pillRect = CGRect(x: (width - pillW) / 2.0, y: pillY - pillH / 2.0, width: pillW, height: pillH)
    let pillBezier = NSBezierPath(roundedRect: pillRect, xRadius: 11, yRadius: 11)
    
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0, height: -1.5)
    shadow.shadowBlurRadius = 5
    shadow.shadowColor = color(hex: 0x000000, alpha: 0.05)
    shadow.set()
    color(hex: 0xFFFFFF, alpha: 0.94).setFill()
    pillBezier.fill()
    
    NSShadow().set()
    color(hex: 0x000000, alpha: 0.075).setStroke()
    pillBezier.lineWidth = 1.0
    pillBezier.stroke()
    
    pStr.draw(at: CGPoint(x: (width - pSize.width) / 2.0, y: pillY - pSize.height / 2.0))

    // Bottom Feature Highlights
    // Finder y = 358 -> Cocoa y = 42
    let featureText = "Instant Sleep Prevention   •   8 Timers (5m – 4h)   •   Native Menu Bar Utility"
    drawCenteredText(
        featureText,
        at: CGPoint(x: width / 2.0, y: 42),
        fontSize: 10.5,
        weight: .medium,
        color: color(hex: 0x8C919C)
    )

    // Optional Preview Icons (for visual verification)
    if includeMockIcons {
        let scriptUrl = URL(fileURLWithPath: CommandLine.arguments[0])
        let repoRoot = scriptUrl.deletingLastPathComponent().deletingLastPathComponent()
        let appIconUrl = repoRoot.appendingPathComponent("Resources/AppIcon.png")
        if let appIconImg = NSImage(contentsOf: appIconUrl) {
            let iconRect = CGRect(x: stayOnCenter.x - 50, y: (height - stayOnCenter.y) - 50, width: 100, height: 100)
            appIconImg.draw(in: iconRect)
        }
        drawCenteredText("StayOn", at: CGPoint(x: stayOnCenter.x, y: 124), fontSize: 12, weight: .regular, color: color(hex: 0x1D1D1F))
        
        let appsIconUrl = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns")
        if let appsIconImg = NSImage(contentsOf: appsIconUrl) {
            let iconRect = CGRect(x: appsCenter.x - 50, y: (height - appsCenter.y) - 50, width: 100, height: 100)
            appsIconImg.draw(in: iconRect)
        }
        drawCenteredText("Applications", at: CGPoint(x: appsCenter.x, y: 124), fontSize: 12, weight: .regular, color: color(hex: 0x1D1D1F))
    }

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    
    return rep
}

// MARK: - Main Execution
let scriptUrl = URL(fileURLWithPath: CommandLine.arguments[0])
let repoRoot = scriptUrl.deletingLastPathComponent().deletingLastPathComponent()
let resourcesDir = repoRoot.appendingPathComponent("Resources")
let buildDir = repoRoot.appendingPathComponent("build")
try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

// 1. Generate 1x (660 x 400)
let rep1x = renderDMGBackground(scale: 1.0, includeMockIcons: false)
let data1x = rep1x.representation(using: .png, properties: [:])!
let out1x = resourcesDir.appendingPathComponent("dmg_background.png")
try! data1x.write(to: out1x)
print("✅ Generated \(out1x.path) (660x400 @1x)")

// 2. Generate 2x (1320 x 800)
let rep2x = renderDMGBackground(scale: 2.0, includeMockIcons: false)
let data2x = rep2x.representation(using: .png, properties: [:])!
let out2x = resourcesDir.appendingPathComponent("dmg_background@2x.png")
try! data2x.write(to: out2x)
print("✅ Generated \(out2x.path) (1320x800 @2x)")

// 3. Generate Mock Preview with Icons overlaid
let repPreview = renderDMGBackground(scale: 2.0, includeMockIcons: true)
let dataPreview = repPreview.representation(using: .png, properties: [:])!
let outPreview = buildDir.appendingPathComponent("dmg_preview.png")
try! dataPreview.write(to: outPreview)
print("✅ Generated preview mockup at \(outPreview.path)")

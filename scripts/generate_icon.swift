// One-off generator for AppIcon.iconset. Draws a rounded-square terracotta
// icon with the same three ascending bars used in the menu bar glyph —
// an original design, not a copy of any existing app's icon.
//
// Usage: swift scripts/generate_icon.swift [output.iconset]

import AppKit

func renderIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap rep")
    }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create graphics context")
    }
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0xE5 / 255, green: 0x7F / 255, blue: 0x4F / 255, alpha: 1),
        NSColor(calibratedRed: 0xB3 / 255, green: 0x4F / 255, blue: 0x2C / 255, alpha: 1)
    ])
    gradient?.draw(in: backgroundPath, angle: -90)

    let barWidth = size * 0.12
    let spacing = size * 0.085
    let baseY = size * 0.27
    let heights: [CGFloat] = [size * 0.20, size * 0.33, size * 0.46]
    let totalWidth = barWidth * 3 + spacing * 2
    var x = (size - totalWidth) / 2

    for h in heights {
        let barRect = NSRect(x: x, y: baseY, width: barWidth, height: h)
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: barWidth * 0.35, yRadius: barWidth * 0.35)
        NSColor.white.withAlphaComponent(0.96).setFill()
        barPath.fill()
        x += barWidth + spacing
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    return data
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let targets: [(name: String, size: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for target in targets {
    let data = renderIcon(pixelSize: target.size)
    let path = "\(outDir)/\(target.name).png"
    try data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) (\(target.size)x\(target.size))")
}

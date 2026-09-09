// Generates the extension store icons (16/32/48/128 px) into extension/icons/.
// White mic.slash glyph on a dark rounded tile; SF Symbols via AppKit.
// Run: swift scripts/gen-icons.swift extension/icons
// Optional sizes: swift scripts/gen-icons.swift <outDir> 16 32 64 128 256 512 1024

import AppKit

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "extension/icons"
let sizes = args.count > 2 ? args.dropFirst(2).compactMap(Int.init) : [16, 32, 48, 128]

func tintedGlyph(pointSize: CGFloat) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
    guard let glyph = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }
    let tinted = NSImage(size: glyph.size)
    tinted.lockFocus()
    glyph.draw(in: NSRect(origin: .zero, size: glyph.size))
    NSColor.white.setFill()
    NSRect(origin: .zero, size: glyph.size).fill(using: .sourceAtop)
    tinted.unlockFocus()
    return tinted
}

func tile(_ px: Int) -> NSImage {
    let s = CGFloat(px)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let radius = s * 0.22
    let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: radius, yRadius: radius)
    NSGradient(
        colors: [
            NSColor(calibratedWhite: 0.26, alpha: 1),
            NSColor(calibratedWhite: 0.09, alpha: 1),
        ]
    )!.draw(in: path, angle: -90)

    if let glyph = tintedGlyph(pointSize: s * 0.58) {
        let gs = glyph.size
        glyph.draw(
            at: NSPoint(x: (s - gs.width) / 2, y: (s - gs.height) / 2),
            from: .zero, operation: .sourceOver, fraction: 1
        )
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, px: Int) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("icon\(px).png")
    try data.write(to: url)
    print("wrote \(url.path)")
}

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for px in sizes {
    try writePNG(tile(px), px: px)
}

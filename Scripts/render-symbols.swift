#!/usr/bin/env swift

// Renders each complication SF Symbol used by the comfort catalog to a PNG, so
// the human-readable COMFORT_TABLE.md can show an actual glyph instead of just a
// symbol name. Run via `just symbols` (or `swift Scripts/render-symbols.swift`).
//
// The glyphs are drawn white on a dark rounded square to mimic how they look on
// a watch face and to stay legible on both light and dark GitHub themes. The
// real complication tint varies with the user's watch-face settings — these
// images are for reviewing the *glyph choice*, not the exact on-device color.
//
// The symbol list is the canonical catalog from ComfortDescriptor.swift; keep it
// in sync if the catalog changes (the `distinctWordsHaveDistinctSymbols` test
// guards the catalog itself, not this list).

import AppKit

// Unique SF Symbols in cold-to-hot order. Duplicates across bands (e.g.
// cloud.fill, sun.max.fill) are rendered once and referenced by name.
let symbols = [
    "thermometer.snowflake",
    "cloud.fog.fill",
    "snowflake",
    "leaf.fill",
    "thermometer.low",
    "humidity.fill",
    "wind",
    "cloud.sun.fill",
    "cloud.drizzle.fill",
    "sun.min.fill",
    "drop.fill",
    "cloud.fill",
    "sun.haze.fill",
    "sun.max.fill",
    "thermometer.high",
    "thermometer.medium",
    "flame.fill",
    "thermometer.sun.fill",
    "sun.dust.fill",
    "exclamationmark.triangle.fill",
    "sun.max.trianglebadge.exclamationmark",
    "exclamationmark.octagon.fill",
]

let outDir = "images/symbols"
let canvas: CGFloat = 96       // points
let scale: CGFloat = 3         // @3x for crisp Retina rendering
let pointSize: CGFloat = 52
let cornerRadius: CGFloat = 22
let background = NSColor(calibratedWhite: 0.11, alpha: 1)
let tint = NSColor.white

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var failures: [String] = []

for name in symbols {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [tint]))
    guard let glyph = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
        failures.append(name)
        continue
    }

    let px = Int(canvas * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
        failures.append(name)
        continue
    }
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let bgRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
    background.setFill()
    bgRect.fill()

    let s = glyph.size
    let drawRect = NSRect(
        x: (canvas - s.width) / 2, y: (canvas - s.height) / 2,
        width: s.width, height: s.height)
    glyph.draw(in: drawRect)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        failures.append(name)
        continue
    }
    try png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("rendered \(name)")
}

if !failures.isEmpty {
    FileHandle.standardError.write(
        "FAILED to render: \(failures.joined(separator: ", "))\n".data(using: .utf8)!)
    exit(1)
}
print("\(symbols.count) symbols → \(outDir)/")

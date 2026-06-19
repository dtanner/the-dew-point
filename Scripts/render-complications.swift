#!/usr/bin/env swift

// Renders the two complications (Word + Icon) as they look on a tinted watch
// face, so the README can show what they look like without a device. Run via
// `just complications` (or `swift Scripts/render-complications.swift`).
//
// This mirrors Scripts/render-symbols.swift: the glance is drawn white on a dark
// rounded background to mimic a watch face and stay legible on both light and
// dark GitHub themes. The real tint varies with the user's watch-face settings —
// this image is for showing the *layout and glyph choice*, not the exact on-device
// color. (The complications can't be screenshotted in the simulator without
// manually placing them on a face, which there's no CLI for.)
//
// The sample shown is `.muggy` — the same representative entry the complication
// previews and gallery placeholder use (ComfortEntry.sample). The word/symbol are
// the canonical values from ComfortDescriptor.swift; keep them in sync if the
// catalog's `.muggy` entry changes.

import AppKit

let word = "Muggy"
let symbolName = "cloud.fill"

let outPath = "images/screenshots/complications.png"
let scale: CGFloat = 3                 // @3x for crisp Retina rendering
let canvas = NSSize(width: 360, height: 200)
let background = NSColor(calibratedWhite: 0.07, alpha: 1)
let tile = NSColor(calibratedWhite: 0.0, alpha: 1)
let tint = NSColor.white
let caption = NSColor(calibratedWhite: 0.55, alpha: 1)

let px = (w: Int(canvas.width * scale), h: Int(canvas.height * scale))
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px.w, pixelsHigh: px.h,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    FileHandle.standardError.write("failed to allocate bitmap\n".data(using: .utf8)!)
    exit(1)
}
rep.size = canvas

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Dark backdrop standing in for the watch face.
background.setFill()
NSBezierPath(roundedRect: NSRect(origin: .zero, size: canvas), xRadius: 28, yRadius: 28).fill()

func centeredCaption(_ text: String, centerX: CGFloat, top: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: caption,
    ]
    let s = NSAttributedString(string: text, attributes: attrs)
    let size = s.size()
    s.draw(at: NSPoint(x: centerX - size.width / 2, y: top - size.height))
}

// --- Icon complication (accessoryCircular): faint dial + SF Symbol ----------
let circleDiameter: CGFloat = 96
let circleCenter = NSPoint(x: 92, y: 116)
let circleRect = NSRect(
    x: circleCenter.x - circleDiameter / 2, y: circleCenter.y - circleDiameter / 2,
    width: circleDiameter, height: circleDiameter)

// AccessoryWidgetBackground stand-in: the standard faint translucent dial.
NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
NSBezierPath(ovalIn: circleRect).fill()

let symConfig = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [tint]))
if let glyph = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(symConfig) {
    let s = glyph.size
    glyph.draw(in: NSRect(
        x: circleCenter.x - s.width / 2, y: circleCenter.y - s.height / 2,
        width: s.width, height: s.height))
} else {
    FileHandle.standardError.write("failed to render symbol \(symbolName)\n".data(using: .utf8)!)
    exit(1)
}
centeredCaption("Icon · circular", centerX: circleCenter.x, top: 56)

// --- Word complication (accessoryRectangular): the comfort word -------------
let rect = NSRect(x: 168, y: 84, width: 168, height: 64)
tile.setFill()
NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).fill()

let wordAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
    .foregroundColor: tint,
]
let wordStr = NSAttributedString(string: word, attributes: wordAttrs)
let wordSize = wordStr.size()
wordStr.draw(at: NSPoint(
    x: rect.midX - wordSize.width / 2, y: rect.midY - wordSize.height / 2))
centeredCaption("Word · rectangular", centerX: rect.midX, top: 56)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try FileManager.default.createDirectory(
    atPath: (outPath as NSString).deletingLastPathComponent,
    withIntermediateDirectories: true)
try png.write(to: URL(fileURLWithPath: outPath))
print("rendered \(outPath)")

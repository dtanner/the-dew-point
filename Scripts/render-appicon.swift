#!/usr/bin/env swift

// Renders the app icon into the asset catalog. Run via `just appicon`
// (or `swift Scripts/render-appicon.swift`).
//
// Matches the app's words-only identity: just the word "Dew" on a deep
// navy-to-teal gradient. watchOS masks icons to a circle, so the word is sized
// to fit the inscribed circle with margin. The PNG must be opaque (no alpha) —
// App Store validation rejects transparent app icons.

import AppKit

let outPath = "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let side = 1024

// An opaque CGContext (NSGraphicsContext can't wrap a no-alpha bitmap rep):
// noneSkipLast keeps the written PNG free of an alpha channel.
guard let cg = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    FileHandle.standardError.write("failed to allocate context\n".data(using: .utf8)!)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

let top = NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.22, alpha: 1)
let bottom = NSColor(calibratedRed: 0.09, green: 0.32, blue: 0.38, alpha: 1)
NSGradient(starting: top, ending: bottom)!
    .draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -90)

// Size the word to the circle watchOS will mask to: cap width well inside the
// 1024pt inscribed circle so nothing gets clipped.
let word = "Dew"
let maxWidth: CGFloat = 620
var fontSize: CGFloat = 300
func attrs(_ size: CGFloat) -> [NSAttributedString.Key: Any] {
    [.font: NSFont.systemFont(ofSize: size, weight: .semibold),
     .foregroundColor: NSColor.white]
}
let measured = NSAttributedString(string: word, attributes: attrs(fontSize)).size()
if measured.width > maxWidth { fontSize *= maxWidth / measured.width }
let str = NSAttributedString(string: word, attributes: attrs(fontSize))
let size = str.size()
// Center the cap-height band, not the full line box (which includes line
// spacing and would leave the word sitting visibly high).
let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
let y = CGFloat(side) / 2 - font.capHeight / 2 + font.descender
str.draw(at: NSPoint(x: (CGFloat(side) - size.width) / 2, y: y))

NSGraphicsContext.restoreGraphicsState()

guard let image = cg.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("rendered \(outPath)")

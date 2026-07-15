#!/usr/bin/env swift

// Renders the app icon into the asset catalog. Run via `just appicon`
// (or `swift Scripts/render-appicon.swift`).
//
// The icon's source of truth is images/icon.svg (a dew drop on a deep
// navy-to-teal field); this script rasterizes it at 1024×1024 for the catalog.
// The PNG must be opaque (no alpha) — App Store validation rejects transparent
// app icons — so the SVG is drawn over a solid background into a no-alpha
// context.

import AppKit

let svgPath = "images/icon.svg"
let outPath = "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let side = 1024

guard let svg = NSImage(contentsOfFile: svgPath) else {
    FileHandle.standardError.write("failed to load \(svgPath)\n".data(using: .utf8)!)
    exit(1)
}

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

NSColor.black.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()
svg.draw(in: NSRect(x: 0, y: 0, width: side, height: side))

NSGraphicsContext.restoreGraphicsState()

guard let image = cg.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("rendered \(outPath) from \(svgPath)")

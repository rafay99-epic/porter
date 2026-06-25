#!/usr/bin/env swift
// Renders Porter's app icon to a 1024×1024 PNG. Usage:
//   swift Scripts/MakeIcon.swift <out.png> [stable|nightly|dev]
// A channel-tinted rounded-rect with the white "tray.and.arrow.down" glyph — the
// same mark the in-app About screen shows. build.sh turns the PNG into an .icns.
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else { fputs("usage: MakeIcon <out.png> [channel]\n", stderr); exit(1) }
let outPath = args[1]
let channel = args.count > 2 ? args[2] : "stable"

let side: CGFloat = 1024

func colors(_ channel: String) -> (NSColor, NSColor) {
    switch channel {
    case "nightly": return (NSColor(srgbRed: 0.98, green: 0.74, blue: 0.18, alpha: 1),
                            NSColor(srgbRed: 0.91, green: 0.55, blue: 0.07, alpha: 1))
    case "dev":     return (NSColor(srgbRed: 0.64, green: 0.45, blue: 0.95, alpha: 1),
                            NSColor(srgbRed: 0.45, green: 0.28, blue: 0.86, alpha: 1))
    default:        return (NSColor(srgbRed: 0.25, green: 0.55, blue: 0.98, alpha: 1),
                            NSColor(srgbRed: 0.10, green: 0.36, blue: 0.86, alpha: 1))
    }
}

let (top, bottom) = colors(channel)
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let full = NSRect(x: 0, y: 0, width: side, height: side)
let bg = NSBezierPath(roundedRect: full.insetBy(dx: side * 0.06, dy: side * 0.06),
                      xRadius: side * 0.225, yRadius: side * 0.225)
NSGradient(starting: top, ending: bottom)?.draw(in: bg, angle: -90)

let cfg = NSImage.SymbolConfiguration(pointSize: side * 0.46, weight: .semibold)
if let raw = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    // Tint the glyph solid white via the source-atop trick.
    let glyph = NSImage(size: raw.size)
    glyph.lockFocus()
    raw.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: raw.size).fill(using: .sourceAtop)
    glyph.unlockFocus()

    let gx = (side - raw.size.width) / 2
    let gy = (side - raw.size.height) / 2
    glyph.draw(at: NSPoint(x: gx, y: gy), from: .zero, operation: .sourceOver, fraction: 1)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("MakeIcon: failed to render PNG\n", stderr); exit(1)
}
try? png.write(to: URL(fileURLWithPath: outPath))

import AppKit
import Foundation

// Locally drawn Dock icon based on the nine-dot geometry shown by the user.
// The installed Tailscale app is a visual reference; no icon bytes are copied.
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("tailscale-dock-\(UUID().uuidString).iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in sizes {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
        pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create \(name)")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    let side = CGFloat(pixels)
    context.compositingOperation = .copy
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    context.compositingOperation = .sourceOver

    NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
    let tile = NSRect(x: side * 0.097, y: side * 0.097, width: side * 0.806, height: side * 0.806)
    NSBezierPath(roundedRect: tile, xRadius: side * 0.17, yRadius: side * 0.17).fill()

    let centers: [CGFloat] = [0.326, 0.5, 0.674]
    let radius = side * 0.056
    for row in 0..<3 {
        for column in 0..<3 {
            let bright = row == 1 || (row == 2 && column == 1)
            if row == 0 && column == 0 {
                NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1).setFill()
            } else {
                NSColor(calibratedWhite: bright ? 0.995 : 0.36, alpha: 1).setFill()
            }
            let circle = NSRect(x: side * centers[column] - radius,
                y: side * centers[2 - row] - radius,
                width: radius * 2, height: radius * 2)
            NSBezierPath(ovalIn: circle).fill()
        }
    }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode \(name)") }
    try data.write(to: iconset.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Generated \(destination.path)")

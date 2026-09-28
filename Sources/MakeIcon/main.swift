import AppKit
import Foundation

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let assetsDir = projectRoot.appendingPathComponent("Assets")
let pngOut = assetsDir.appendingPathComponent("icon-1024.png")
let icnsOut = projectRoot.appendingPathComponent("AppIcon.icns")

// 1 = wall, 0 = floor
let maze: [[Int]] = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1, 0, 0, 0, 1],
    [1, 0, 1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 0, 1, 0, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 1, 1, 1, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1],
]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let pad = CGFloat(size) * 0.06
    let inner = NSRect(x: pad, y: pad, width: CGFloat(size) - pad * 2, height: CGFloat(size) - pad * 2)
    let bg = NSBezierPath(roundedRect: inner, xRadius: inner.width * 0.18, yRadius: inner.height * 0.18)
    NSColor(calibratedRed: 0.015, green: 0.05, blue: 0.025, alpha: 1).setFill()
    bg.fill()

    let grid = 9
    let cell = (inner.width * 0.82) / CGFloat(grid)
    let ox = inner.midX - cell * CGFloat(grid) / 2
    let oy = inner.midY - cell * CGFloat(grid) / 2

    for row in 0..<grid {
        for col in 0..<grid {
            let rect = NSRect(
                x: ox + CGFloat(col) * cell + 2,
                y: oy + CGFloat(grid - 1 - row) * cell + 2,
                width: cell - 4,
                height: cell - 4
            )
            if maze[row][col] == 1 {
                NSColor(calibratedRed: 0.08, green: 0.78, blue: 0.32, alpha: 1).setFill()
            } else {
                let alt = (row + col) % 2 == 0
                NSColor(
                    calibratedRed: 0.02,
                    green: alt ? 0.12 : 0.16,
                    blue: alt ? 0.05 : 0.07,
                    alpha: 1
                ).setFill()
            }
            NSBezierPath(rect: rect).fill()
        }
    }

    func glowDot(at point: NSPoint, radius: CGFloat, color: NSColor) {
        for scale in [1.4, 1.0, 0.55] {
            let r = radius * scale
            let alpha = scale == 1.0 ? 1.0 : 0.22
            color.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)).fill()
        }
    }

    let player = NSPoint(x: ox + cell * 1.5, y: oy + cell * 1.5)
    glowDot(at: player, radius: cell * 0.22, color: NSColor(calibratedRed: 0.35, green: 1, blue: 0.5, alpha: 1))

    let snipeCenter = NSPoint(x: ox + cell * 6.5, y: oy + cell * 6.5)
    let d = cell * 0.32
    let diamond = NSBezierPath()
    diamond.move(to: NSPoint(x: snipeCenter.x, y: snipeCenter.y + d))
    diamond.line(to: NSPoint(x: snipeCenter.x + d, y: snipeCenter.y))
    diamond.line(to: NSPoint(x: snipeCenter.x, y: snipeCenter.y - d))
    diamond.line(to: NSPoint(x: snipeCenter.x - d, y: snipeCenter.y))
    diamond.close()
    NSColor(calibratedRed: 1, green: 0.62, blue: 0.08, alpha: 0.35).setFill()
    diamond.fill()
    NSColor(calibratedRed: 1, green: 0.75, blue: 0.2, alpha: 1).setFill()
    diamond.fill()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "MakeIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG export failed"])
    }
    try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    try data.write(to: url)
}

func resizedPNG(from source: NSImage, side: Int) -> Data? {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    source.draw(
        in: NSRect(x: 0, y: 0, width: side, height: side),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else { return nil }
    return rep.representation(using: .png, properties: [:])
}

func buildICNS(from source: NSImage) throws {
    let iconset = projectRoot.appendingPathComponent("AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

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
        (1024, "icon_512x512@2x.png"),
    ]

    for (side, name) in sizes {
        guard let data = resizedPNG(from: source, side: side) else { continue }
        try data.write(to: iconset.appendingPathComponent(name))
    }

    try? FileManager.default.removeItem(at: icnsOut)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", icnsOut.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "MakeIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
    }
    try? FileManager.default.removeItem(at: iconset)
}

func run() {
    do {
        let icon = drawIcon(size: 1024)
        try savePNG(icon, to: pngOut)
        try buildICNS(from: icon)
        print("Wrote \(pngOut.path)")
        print("Wrote \(icnsOut.path)")
    } catch {
        fputs("MakeIcon error: \(error)\n", stderr)
        exit(1)
    }
}

run()
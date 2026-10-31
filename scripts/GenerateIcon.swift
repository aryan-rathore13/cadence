import AppKit

let folder = URL(fileURLWithPath: "dist/AppIcon.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let rect = NSRect(x: p * 0.07, y: p * 0.07, width: p * 0.86, height: p * 0.86)
        let shape = NSBezierPath(roundedRect: rect, xRadius: p * 0.20, yRadius: p * 0.20)
        NSGradient(starting: NSColor(red: 0.68, green: 0.57, blue: 1, alpha: 1),
                   ending: NSColor(red: 0.36, green: 0.27, blue: 0.76, alpha: 1))!.draw(in: shape, angle: -65)
        let heights: [CGFloat] = [0.16, 0.32, 0.49, 0.25, 0.40]
        NSColor.white.withAlphaComponent(0.96).setFill()
        for (index, height) in heights.enumerated() {
            let width = p * 0.065
            let bar = NSRect(x: p * (0.265 + CGFloat(index) * 0.105), y: p * (0.5 - height / 2), width: width, height: p * height)
            NSBezierPath(roundedRect: bar, xRadius: width / 2, yRadius: width / 2).fill()
        }
        image.unlockFocus()
        let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

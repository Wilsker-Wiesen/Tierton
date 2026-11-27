// Renders the 1024×1024 app icon: design no. 41 from the icon gallery
// ("Tukan mit Klangkreisen": green gradient, yellow sound rings, cut-out toucan).
// Geometry is the gallery's 100×100 SVG, scaled ×10.24.
// Usage: swift tools/make_icon.swift <toucan.heic> <out.png>
import AppKit

let args = CommandLine.arguments
let toucan = NSImage(contentsOf: URL(fileURLWithPath: args[1]))!
let S: CGFloat = 1024, u = S / 100

let img = NSImage(size: NSSize(width: S, height: S), flipped: true) { _ in
    // background: top #47AE74 → bottom #1C6A42
    NSGradient(starting: NSColor(srgbRed: 0x47 / 255.0, green: 0xAE / 255.0, blue: 0x74 / 255.0, alpha: 1),
               ending: NSColor(srgbRed: 0x1C / 255.0, green: 0x6A / 255.0, blue: 0x42 / 255.0, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: S, height: S), angle: 90)
    // sound rings centred at (62, 42): dot r 8, rings r 18 / 28 / 38
    let yellow = NSColor(srgbRed: 1, green: 0xC9 / 255.0, blue: 0x4A / 255.0, alpha: 1)
    let c = CGPoint(x: 62 * u, y: 42 * u)
    yellow.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - 8 * u, y: c.y - 8 * u, width: 16 * u, height: 16 * u)).fill()
    for (i, r) in [18.0, 28.0, 38.0].enumerated() {
        let p = NSBezierPath(ovalIn: NSRect(x: c.x - r * u, y: c.y - r * u, width: 2 * r * u, height: 2 * r * u))
        p.lineWidth = 3.6 * u
        yellow.withAlphaComponent(1 - CGFloat(i + 1) * 0.22).setStroke()
        p.stroke()
    }
    // toucan: width 88, x 4, y 32
    let w = 88 * u, h = w * toucan.size.height / toucan.size.width
    toucan.draw(in: NSRect(x: 4 * u, y: 32 * u, width: w, height: h), from: .zero,
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    return true
}
let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let rep = NSBitmapImageRep(cgImage: cg)
rep.size = NSSize(width: S, height: S)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("icon written")

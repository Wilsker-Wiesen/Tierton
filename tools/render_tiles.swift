// Renders single cut-out animals as PNG tiles in the app's pop-out style (habitat-coloured circle),
// e.g. for the photo-choice page. Usage: swift tools/render_tiles.swift <out-dir> <size> <id>=<image> ...
import AppKit

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args[1])
let S = CGFloat(Double(args[2])!)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

struct Cat: Decodable { let id: String; let color: String }
struct Ani: Decodable { let id: String; let category: String }
struct Catalog: Decodable { let categories: [Cat]; let animals: [Ani] }
let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: URL(fileURLWithPath: "Content/catalog.json")))
let colorOf = Dictionary(uniqueKeysWithValues: catalog.categories.map { ($0.id, $0.color) })
let catOf = Dictionary(uniqueKeysWithValues: catalog.animals.map { ($0.id, $0.category) })

func nsColor(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

/// Mirrors PopOutLayout in Components.swift (top-left origin).
func layout(w: CGFloat, h: CGFloat, circle: CGRect, image: CGSize) -> CGRect {
    let d = circle.width
    let aspect = image.width / max(image.height, 1)
    if aspect > 1.25 {
        let ih = min(w / aspect, h * 0.9), iw = ih * aspect
        let bottom = min(circle.maxY - d * 0.05, circle.midY - d * 0.06 + ih / 2)
        return CGRect(x: (w - iw) / 2, y: bottom - ih, width: iw, height: ih)
    }
    let s = min(w * 0.92 / image.width, h * 0.95 / image.height)
    let iw = image.width * s, ih = image.height * s
    return CGRect(x: (w - iw) / 2, y: circle.maxY - d * 0.05 - ih, width: iw, height: ih)
}

for spec in args.dropFirst(3) {
    let parts = spec.split(separator: "=", maxSplits: 1).map(String.init)
    let name = parts[0], path = parts[1]
    let id = String(name.split(separator: "_").first ?? "")
    guard let a = NSImage(contentsOf: URL(fileURLWithPath: path)) else { print("skip \(name)"); continue }
    let tint = nsColor(colorOf[catOf[id] ?? ""] ?? "#888888")
    let img = NSImage(size: NSSize(width: S, height: S), flipped: true) { _ in
        let d = S * 0.84
        let circle = CGRect(x: (S - d) / 2, y: S * 0.97 - d, width: d, height: d)
        tint.withAlphaComponent(0.28).setFill()
        NSBezierPath(ovalIn: circle).fill()
        let clip = NSBezierPath(ovalIn: circle)
        clip.append(NSBezierPath(rect: NSRect(x: 0, y: 0, width: S, height: circle.midY)))
        clip.addClip()
        a.draw(in: layout(w: S, h: S, circle: circle, image: a.size), from: .zero, operation: .sourceOver,
               fraction: 1, respectFlipped: true, hints: nil)
        return true
    }
    let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let rep = NSBitmapImageRep(cgImage: cg)
    // WebP isn't writable by AppKit; PNG keeps the transparent corners.
    try rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(name).png"))
}
print("rendered \(args.count - 3) tiles")

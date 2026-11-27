// Renders a contact sheet of cut-out animals exactly in the app's "peek out of the circle" style
// (habitat colour, layout, names) so the cut-outs can be reviewed at a glance.
// Usage: swift tools/contact_sheet.swift <image-dir> <out.png> [columns] [catalog.json]
import AppKit

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let cols = args.count > 3 ? Int(args[3])! : 8
let catalogPath = args.count > 4 ? args[4] : "Content/catalog.json"

struct Cat: Decodable { let id: String; let color: String }
struct Ani: Decodable { let id: String; let name: String; let category: String }
struct Catalog: Decodable { let categories: [Cat]; let animals: [Ani] }
let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: URL(fileURLWithPath: catalogPath)))
let colorOf = Dictionary(uniqueKeysWithValues: catalog.categories.map { ($0.id, $0.color) })
let animalOf = Dictionary(uniqueKeysWithValues: catalog.animals.map { ($0.id, $0) })
let order = Dictionary(uniqueKeysWithValues: catalog.animals.enumerated().map { ($1.id, $0) })

func nsColor(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { ["png", "heic"].contains($0.pathExtension) }
    .sorted { (order[$0.deletingPathExtension().lastPathComponent] ?? 999) < (order[$1.deletingPathExtension().lastPathComponent] ?? 999) }
let tile: CGFloat = 220, label: CGFloat = 30
let rows = (files.count + cols - 1) / cols
let size = NSSize(width: CGFloat(cols) * tile, height: CGFloat(rows) * (tile + label))

/// Mirrors PopOutLayout in Components.swift (top-left origin).
func layout(w: CGFloat, h: CGFloat, circle: CGRect, image: CGSize) -> CGRect {
    let d = circle.width
    let aspect = image.width / max(image.height, 1)
    if aspect > 1.25 {
        let ih = min(w / aspect, h * 0.9), iw = ih * aspect
        let cy = circle.midY - d * 0.06
        let bottom = min(circle.maxY - d * 0.05, cy + ih / 2)
        return CGRect(x: (w - iw) / 2, y: bottom - ih, width: iw, height: ih)
    }
    let s = min(w * 0.92 / image.width, h * 0.95 / image.height)
    let iw = image.width * s, ih = image.height * s
    return CGRect(x: (w - iw) / 2, y: circle.maxY - d * 0.05 - ih, width: iw, height: ih)
}

let sheet = NSImage(size: size, flipped: true) { _ in
    NSColor(white: 0.97, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    for (i, f) in files.enumerated() {
        guard let a = NSImage(contentsOf: f) else { continue }
        let id = f.deletingPathExtension().lastPathComponent
        let info = animalOf[id]
        let tint = nsColor(colorOf[info?.category ?? ""] ?? "#888888")
        let ox = CGFloat(i % cols) * tile, oy = CGFloat(i / cols) * (tile + label)
        let card = NSRect(x: ox + 5, y: oy + 5, width: tile - 10, height: tile + label - 10)
        NSColor(white: 0.93, alpha: 1).setFill()
        NSBezierPath(roundedRect: card, xRadius: 18, yRadius: 18).fill()
        let w = tile - 16, h = tile - 16
        let d = min(w, h) * 0.84
        let circle = CGRect(x: ox + 8 + (w - d) / 2, y: oy + 8 + h * 0.97 - d, width: d, height: d)
        tint.withAlphaComponent(0.28).setFill()
        NSBezierPath(ovalIn: circle).fill()
        NSGraphicsContext.saveGraphicsState()
        let clip = NSBezierPath(ovalIn: circle)
        clip.append(NSBezierPath(rect: NSRect(x: ox + 8, y: oy + 8, width: w, height: circle.midY - (oy + 8))))
        clip.addClip()
        var r = layout(w: w, h: h, circle: circle.offsetBy(dx: -(ox + 8), dy: -(oy + 8)), image: a.size)
        r = r.offsetBy(dx: ox + 8, dy: oy + 8)
        a.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        let name = (info?.name ?? id) as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: NSColor.black]
        let ns = name.size(withAttributes: attrs)
        name.draw(at: NSPoint(x: ox + (tile - ns.width) / 2, y: oy + tile - 6), withAttributes: attrs)
    }
    return true
}
let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(files.count) tiles")

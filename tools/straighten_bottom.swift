// Replaces a ragged bottom edge of a cut-out with a straight, slightly soft line.
// The cut is placed at the lowest row where the animal is still at least `fraction` as wide as
// its widest row, so ragged leftovers (rocks, water, grass) below that line disappear.
// Usage: swift tools/straighten_bottom.swift <in.heic> <out.heic> [fraction=0.8]
import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

let args = CommandLine.arguments
let inURL = URL(fileURLWithPath: args[1]), outURL = URL(fileURLWithPath: args[2])
let fraction = args.count > 3 ? Double(args[3])! : 0.8

guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("cannot read") }
let w = img.width, h = img.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

// px rows are top-down in memory for this context
func width(_ y: Int) -> Int { (0..<w).reduce(0) { $0 + (px[(y * w + $1) * 4 + 3] > 128 ? 1 : 0) } }
let widths = (0..<h).map(width)
let maxW = widths.max() ?? 0
let target = Int(Double(maxW) * fraction)
// lowest row (largest y) that is still wide enough
let cutY = (0..<h).last { widths[$0] >= target } ?? h - 1
let feather = 3
for y in 0..<h {
    let factor: Double = y <= cutY - feather ? 1 : y > cutY ? 0 : Double(cutY - y) / Double(feather)
    if factor >= 1 { continue }
    for x in 0..<w {
        let i = (y * w + x) * 4
        for c in 0..<4 { px[i + c] = UInt8(Double(px[i + c]) * factor) }
    }
}
let out = ctx.makeImage()!.cropping(to: CGRect(x: 0, y: 0, width: w, height: cutY + 1))!
let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.heic.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
CGImageDestinationFinalize(dest)
print("cut at row \(cutY) of \(h) (max width \(maxW), target \(target))")

// Softens a hard cut on one side of a cut-out by fading the outermost part to transparent.
// Usage: swift tools/fade_edge.swift <in.heic> <out.heic> <left|right|top> [fraction=0.18]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
let side = a[3], frac = a.count > 4 ? Double(a[4])! : 0.18
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let span = Double(side == "top" ? h : w) * frac
for y in 0..<h { for x in 0..<w {
    let d: Double = side == "right" ? Double(w - 1 - x) : side == "left" ? Double(x) : Double(y)
    guard d < span else { continue }
    let t = d / span, f = t * t * (3 - 2 * t)   // smoothstep
    let i = (y * w + x) * 4
    for c in 0..<4 { px[i + c] = UInt8(Double(px[i + c]) * f) }
} }
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.heic.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
CGImageDestinationFinalize(dest)
print("faded \(side)")

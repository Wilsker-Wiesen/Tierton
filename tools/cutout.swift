// Cuts the animal out of each photo with Apple's Vision subject-lifting (macOS 14+)
// and writes a transparent PNG cropped to the animal.
//
// Usage: swift tools/cutout.swift <input-dir-with-jpgs> <output-dir> [id ...]
import AppKit
import CoreImage
import Foundation
import Vision
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: cutout.swift <in> <out> [ids]"); exit(1)
}
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let only = Set(args.dropFirst(3))
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let ctx = CIContext()
let maxSide: CGFloat = CGFloat(Double(ProcessInfo.processInfo.environment["CUTOUT_MAX"] ?? "640") ?? 640)
var lastEdges = ""

func cutout(_ url: URL) throws -> (CGImage, Double)? {
    guard let src = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { return nil }
    let handler = VNImageRequestHandler(ciImage: src)
    let req = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([req])
    guard let obs = req.results?.first, !obs.allInstances.isEmpty else { return nil }
    // Count pixels per instance in the low-res instance mask; keep the largest instance and
    // any other instance at least 35 % as big (e.g. a penguin family), drop small extras.
    let im = obs.instanceMask
    CVPixelBufferLockBaseAddress(im, .readOnly)
    let w = CVPixelBufferGetWidth(im), h = CVPixelBufferGetHeight(im), rb = CVPixelBufferGetBytesPerRow(im)
    let base = CVPixelBufferGetBaseAddress(im)!.assumingMemoryBound(to: UInt8.self)
    var area = [Int: Int]()
    for y in 0..<h { for x in 0..<w { let v = Int(base[y * rb + x]); if v > 0 { area[v, default: 0] += 1 } } }
    let biggest = area.values.max() ?? 0
    let keepFrac = Double(ProcessInfo.processInfo.environment["CUTOUT_KEEP"] ?? "0.35") ?? 0.35
    var keep = IndexSet(area.filter { Double($0.value) >= keepFrac * Double(biggest) }.map(\.key))
    if keep.isEmpty { keep = obs.allInstances }
    // Which photo borders does the kept animal touch? (top/left/right = animal is cut off)
    var edges = Set<Character>()
    for y in 0..<h { for x in 0..<w where keep.contains(Int(base[y * rb + x])) {
        if x <= 1 { edges.insert("L") }; if x >= w - 2 { edges.insert("R") }
        if y <= 1 { edges.insert("T") }; if y >= h - 2 { edges.insert("B") }
    } }
    CVPixelBufferUnlockBaseAddress(im, .readOnly)
    lastEdges = String(edges.sorted())
    let mask = try obs.generateScaledMaskForImage(forInstances: keep, from: handler)
    let pb = try obs.generateMaskedImage(ofInstances: keep, from: handler, croppedToInstancesExtent: true)
    var img = CIImage(cvPixelBuffer: pb)
    // coverage = share of the photo that is "subject" (a sanity metric for review)
    let maskImg = CIImage(cvPixelBuffer: mask)
    let avg = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: maskImg, kCIInputExtentKey: CIVector(cgRect: maskImg.extent)])!.outputImage!
    var px = [UInt8](repeating: 0, count: 4)
    ctx.render(avg, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
    let coverage = Double(px[0]) / 255
    let scale = min(1, maxSide / max(img.extent.width, img.extent.height))
    if scale < 1 {
        img = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
    }
    guard let cg = ctx.createCGImage(img, from: img.extent.integral, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { return nil }
    return (cg, coverage)
}

let files = try FileManager.default.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
for f in files {
    let id = f.deletingPathExtension().lastPathComponent
    if !only.isEmpty && !only.contains(id) { continue }
    do {
        guard let (cg, coverage) = try cutout(f) else { print("\(id)\tFAILED no subject"); continue }
        // HEIC keeps the alpha channel at a fraction of the PNG size.
        let dst = outDir.appendingPathComponent("\(id).heic")
        guard let d = CGImageDestinationCreateWithURL(dst as CFURL, UTType.heic.identifier as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(d, cg, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
        CGImageDestinationFinalize(d)
        print("\(id)\t\(cg.width)x\(cg.height)\tcoverage=\(String(format: "%.2f", coverage))\tedges=\(lastEdges)")
    } catch {
        print("\(id)\tFAILED \(error.localizedDescription)")
    }
}

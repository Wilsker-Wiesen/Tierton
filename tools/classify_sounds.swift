// Quality check for animal sounds with Apple's built-in sound classifier (SoundAnalysis).
// Prints, per file, the strongest sound classes and flags speech/music contamination.
// Usage: swift tools/classify_sounds.swift <dir-with-m4a> [id ...]
import AVFoundation
import Foundation
import SoundAnalysis

final class Collector: NSObject, SNResultsObserving {
    var scores: [String: Double] = [:]
    var windows = 0
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let r = result as? SNClassificationResult else { return }
        windows += 1
        for c in r.classifications where c.confidence > 0.05 {
            scores[c.identifier, default: 0] = max(scores[c.identifier, default: 0], c.confidence)
        }
    }
}

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let only = Set(args.dropFirst(2))
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "m4a" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
let bad: Set<String> = ["speech", "music", "singing", "shout", "conversation", "narration_monologue", "musical_instrument",
                        "laughter", "child_speech_kid_speaking", "male_speech_man_speaking", "female_speech_woman_speaking", "engine", "vehicle"]

for f in files {
    let id = f.deletingPathExtension().lastPathComponent
    if !only.isEmpty && !only.contains(id) { continue }
    do {
        let analyzer = try SNAudioFileAnalyzer(url: f)
        let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
        req.windowDuration = CMTime(seconds: 1.5, preferredTimescale: 48000)
        let col = Collector()
        try analyzer.add(req, withObserver: col)
        analyzer.analyze()
        let top = col.scores.sorted { $0.value > $1.value }.prefix(5)
        let flags = col.scores.filter { bad.contains($0.key) && $0.value > 0.5 }.map { $0.key }
        print("\(id)\t\(flags.isEmpty ? "ok  " : "WARN")\t" + top.map { "\($0.key) \(Int($0.value * 100))" }.joined(separator: ", ")
              + (flags.isEmpty ? "" : "\t!! \(flags.joined(separator: ","))"))
    } catch {
        print("\(id)\tFAIL\t\(error.localizedDescription)")
    }
}

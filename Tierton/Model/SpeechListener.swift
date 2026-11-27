import AVFoundation
import Speech
import SwiftUI

/// Listens to the microphone and transcribes German speech live (any voice, no training).
/// Uses on-device recognition when the device supports it, and the voice-processing input
/// (echo cancellation) so the animal sound coming out of the speaker isn't "heard" as an answer.
@Observable
final class SpeechListener {
    enum State: Equatable { case idle, listening, denied, unavailable }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    /// Every alternative the recognizer considered (helps matching unusual names).
    private(set) var alternatives: [String] = []

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Asks for microphone + speech permission once. Returns whether listening is possible.
    func authorize() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speech == .authorized else { state = .denied; return false }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { state = .denied; return false }
        guard recognizer?.isAvailable == true else { state = .unavailable; return false }
        return true
    }

    /// Starts a fresh recognition. `hints` (animal names) make those words more likely to be recognized.
    func start(hints: [String]) {
        stop()
        transcript = ""
        alternatives = []
        guard let recognizer, recognizer.isAvailable else { state = .unavailable; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.defaultToSpeaker, .allowBluetoothA2DP, .duckOthers])
            try session.setActive(true)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.contextualStrings = Array(hints.prefix(100))
            req.taskHint = .search
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            request = req

            let input = engine.inputNode
            try? input.setVoiceProcessingEnabled(true)
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
                req?.append(buffer)
            }
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let best = result.bestTranscription.formattedString
                    let alts = result.transcriptions.map(\.formattedString)
                    DispatchQueue.main.async {
                        self.transcript = best
                        self.alternatives = alts
                    }
                }
                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async { if self.state == .listening { self.stopEngine() } }
                }
            }
            state = .listening
        } catch {
            stop()
            state = .unavailable
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        stopEngine()
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        if state == .listening { state = .idle }
        // back to plain playback so sounds are loud again (voice-chat mode is quieter)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
    }
}

/// Decides whether what someone said names the right animal.
enum AnswerMatcher {
    enum Verdict: Equatable {
        case correct            // said the animal (or a synonym)
        case close(String)      // said the group, e.g. "Pinguin" for Kaiserpinguin → hint with full name
        case wrong(Animal)      // clearly named another animal
        case none               // nothing recognizable yet
    }

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "-", with: "")
            .filter { $0.isLetter || $0 == " " }
    }

    /// All forms that count as exactly this animal.
    static func names(of a: Animal) -> [String] {
        ([a.name] + (a.say ?? [])).map(normalize).map { $0.replacingOccurrences(of: " ", with: "") }
    }

    /// Spoken words plus neighbouring pairs/triples joined ("kaiser pinguin" → "kaiserpinguin").
    static func tokens(_ texts: [String]) -> Set<String> {
        var out = Set<String>()
        for t in texts {
            let w = normalize(t).split(separator: " ").map(String.init)
            for i in w.indices {
                out.insert(w[i])
                if i + 1 < w.count { out.insert(w[i] + w[i + 1]) }
                if i + 2 < w.count { out.insert(w[i] + w[i + 1] + w[i + 2]) }
            }
        }
        return out.filter { $0.count >= 2 }
    }

    static func verdict(texts: [String], answer: Animal, pool: [Animal]) -> Verdict {
        let toks = tokens(texts)
        guard !toks.isEmpty else { return .none }
        let target = names(of: answer)
        // 1. exact or almost exact (one or two letters off for longer words)
        for t in toks {
            for n in target where t == n || similar(t, n) { return .correct }
        }
        // 2. the group word: "pinguin" for kaiserpinguin, "wal" for buckelwal, "eule" for schneeeule
        for t in toks where t.count >= 3 {
            for n in target where n.hasSuffix(t) && n != t { return .close(answer.name) }
        }
        // 3. clearly another animal
        for a in pool where a.id != answer.id && a.sci != answer.sci {
            for n in names(of: a) where toks.contains(n) { return .wrong(a) }
        }
        return .none
    }

    static func similar(_ a: String, _ b: String) -> Bool {
        let m = max(a.count, b.count)
        guard m >= 5, abs(a.count - b.count) <= 2 else { return false }
        return levenshtein(a, b) <= (m >= 8 ? 2 : 1)
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var prev = Array(0...b.count)
        for i in 1...max(a.count, 1) where !a.isEmpty {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...max(b.count, 1) where !b.isEmpty {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return a.isEmpty ? b.count : prev[b.count]
    }
}

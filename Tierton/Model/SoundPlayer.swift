import AVFoundation
import SwiftUI

/// Plays one animal sound at a time and publishes which animal is currently playing.
@Observable
final class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: String?
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        // .playback so sounds are audible even with the silent switch on – it's the whole point of the app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
    }

    func play(_ animal: Animal, from store: AnimalStore) {
        guard let url = store.soundURL(for: animal) else { return }
        player?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            player = p
            playingID = animal.id
        } catch {
            playingID = nil
        }
    }

    /// Plays the sound, or stops it if this animal is already playing.
    func toggle(_ animal: Animal, from store: AnimalStore) {
        if playingID == animal.id { stop() } else { play(animal, from: store) }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            if self?.player === player { self?.playingID = nil }
        }
    }
}

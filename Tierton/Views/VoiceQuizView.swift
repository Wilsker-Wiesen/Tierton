import SwiftUI

/// "Sag's laut!": a sound plays, the animal stays hidden, and you simply say its name.
struct VoiceQuizView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player
    @Environment(\.openURL) private var openURL
    @State private var listener = SpeechListener()

    enum Phase: Equatable { case setup, asking, revealed, finished }
    struct Round { let answer: Animal; var result: Result = .open; let started = Date(); var points = 0 }
    enum Result: Equatable { case open, right, close, gaveUp }

    static let roundsPerGame = 10
    private let accent = Color(hex: "#8E5BB5")

    @State private var phase: Phase = .setup
    @State private var selected: Set<String> = []
    @State private var birdsOnly = false
    @State private var rounds: [Round] = []
    @State private var score = 0
    @State private var wrongGuess: Animal?
    @State private var detail: Animal?
    @AppStorage("voiceBest") private var best = 0

    private var pool: [Animal] { store.pool(categories: selected, birdsOnly: birdsOnly) }

    var body: some View {
        Group {
            switch phase {
            case .setup: setup
            case .asking: asking
            case .revealed: revealed
            case .finished: results
            }
        }
        .animation(.snappy, value: phase)
        .navigationTitle("Sag's laut!")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { AnimalDetailView(animal: $0) }
        .onChange(of: listener.transcript) { evaluate() }
        .onDisappear { listener.stop(); player.stop() }
    }

    // MARK: Setup

    private var setup: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(accent)
                    .padding(.top, 20)
                Text("Du hörst ein Tier, aber du siehst es nicht. Sag einfach laut, welches Tier das ist!")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("Zum Beispiel: „Kuh“, „Amsel“ oder „Buckelwal“. Es reicht auch „Pinguin“ oder „Wal“.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tiere").font(.headline).padding(.horizontal)
                    CategoryFilter(selected: $selected, birdsOnly: $birdsOnly)
                    Text("\(pool.count) Tiere in der Auswahl").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
                }
                if best > 0 {
                    Label("Rekord: \(best) Punkte", systemImage: "trophy.fill").font(.headline).foregroundStyle(.orange)
                }
                if listener.state == .denied {
                    VStack(spacing: 8) {
                        Text("Tierton braucht Mikrofon und Spracherkennung. Du kannst das in den Einstellungen erlauben.")
                            .font(.footnote).multilineTextAlignment(.center)
                        Button("Einstellungen öffnen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    .padding(.horizontal)
                } else if listener.state == .unavailable {
                    Text("Spracherkennung ist gerade nicht verfügbar. Prüfe die Internetverbindung oder versuch es gleich nochmal.")
                        .font(.footnote).multilineTextAlignment(.center).padding(.horizontal)
                }
                BigButton(title: "Los geht's", symbol: "play.fill", color: accent) {
                    Task { if await listener.authorize() { startGame() } }
                }
                .disabled(pool.isEmpty)
                .padding(.horizontal)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
    }

    // MARK: Asking

    private var asking: some View {
        let round = rounds.last
        let playing = round.map { player.playingID == $0.answer.id } ?? false
        let listening = listener.state == .listening
        return VStack(spacing: 18) {
            header
            Spacer()
            Button { if let a = round?.answer { player.play(a, from: store) } } label: {
                ZStack {
                    Circle().fill(accent.opacity(0.15)).frame(width: 230, height: 230)
                    Circle().stroke(accent.opacity(listening ? 0.6 : 0), lineWidth: 6)
                        .frame(width: 250, height: 250)
                        .scaleEffect(listening ? 1.04 : 1)
                        .animation(listening ? .easeInOut(duration: 0.9).repeatForever() : .default, value: listening)
                    Image(systemName: playing ? "speaker.wave.3.fill" : "questionmark")
                        .font(.system(size: 96, weight: .heavy))
                        .foregroundStyle(accent)
                        .symbolEffect(.variableColor.iterative, isActive: playing)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geräusch nochmal abspielen")

            Text(playing ? "Hör genau hin …" : "Welches Tier ist das?")
                .font(.title.bold())

            // what the microphone heard
            VStack(spacing: 6) {
                if listening {
                    Label("Ich höre zu …", systemImage: "mic.fill")
                        .font(.headline).foregroundStyle(accent)
                        .symbolEffect(.pulse, isActive: true)
                } else {
                    Button { listen() } label: {
                        Label("Antwort sagen", systemImage: "mic.fill")
                            .font(.headline).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text(listener.transcript.isEmpty ? " " : "„\(listener.transcript)“")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let w = wrongGuess {
                    Text("\(w.name)? Nein, versuch's nochmal!")
                        .font(.headline).foregroundStyle(.red)
                        .transition(.opacity)
                }
            }
            .frame(minHeight: 110)
            .padding(.horizontal)

            Spacer()
            HStack(spacing: 12) {
                BigButton(title: "Nochmal hören", symbol: "arrow.counterclockwise", color: .gray) {
                    if let a = round?.answer { player.play(a, from: store) }
                }
                BigButton(title: "Weiß nicht", symbol: "eye.fill", color: accent) { reveal(.gaveUp) }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            Text("Runde \(rounds.count)/\(Self.roundsPerGame)").font(.headline)
            Spacer()
            Text("\(score) Punkte").font(.headline.monospacedDigit()).contentTransition(.numericText())
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: Revealed

    private var revealed: some View {
        let round = rounds.last!
        let a = round.answer
        return VStack(spacing: 14) {
            header
            AnimalPhoto(animal: a, circleOpacity: 0.32)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 400, maxHeight: 360)
                .padding(.horizontal)
                .onTapGesture { player.toggle(a, from: store) }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            Text(a.name).font(.largeTitle.bold())
            Group {
                switch round.result {
                case .right: Label("Richtig! +\(round.points)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .close: Label("Fast genau! Es ist ein \(a.name). +\(round.points)", systemImage: "checkmark.circle").foregroundStyle(.green)
                default: Label("Das war: \(a.name)", systemImage: "lightbulb.fill").foregroundStyle(.orange)
                }
            }
            .font(.title3.bold())
            .multilineTextAlignment(.center)
            Button { detail = a } label: { Label("Mehr über das Tier", systemImage: "info.circle.fill") }
            Spacer()
            BigButton(title: rounds.count >= Self.roundsPerGame ? "Ergebnis" : "Nächstes Tier", symbol: "forward.fill", color: accent) {
                nextRound()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    // MARK: Results

    private var results: some View {
        let right = rounds.filter { $0.result == .right || $0.result == .close }.count
        return ScrollView {
            VStack(spacing: 16) {
                Image(systemName: right >= 8 ? "trophy.fill" : right >= 5 ? "star.fill" : "hand.thumbsup.fill")
                    .font(.system(size: 80)).foregroundStyle(.orange).padding(.top, 30)
                Text("\(score) Punkte").font(.system(size: 44, weight: .heavy, design: .rounded))
                Text("\(right) von \(Self.roundsPerGame) erkannt").font(.title3)
                ForEach(Array(rounds.enumerated()), id: \.offset) { _, r in
                    Button { detail = r.answer } label: {
                        HStack {
                            AnimalPhoto(animal: r.answer).frame(width: 52, height: 52)
                            Text(r.answer.name).font(.headline)
                            Spacer()
                            Image(systemName: r.result == .gaveUp ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(r.result == .gaveUp ? .red : .green)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                HStack(spacing: 12) {
                    BigButton(title: "Einstellungen", symbol: "slider.horizontal.3", color: .gray) { phase = .setup }
                    BigButton(title: "Nochmal", symbol: "arrow.counterclockwise", color: accent) { startGame() }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Logic

    private func startGame() {
        score = 0
        rounds = []
        nextRound()
    }

    private func nextRound() {
        if rounds.count >= Self.roundsPerGame {
            listener.stop(); player.stop()
            best = max(best, score)
            phase = .finished
            return
        }
        let used = Set(rounds.map(\.answer.id))
        guard let a = pool.filter({ !used.contains($0.id) }).randomElement() ?? pool.randomElement() else { return }
        rounds.append(Round(answer: a))
        wrongGuess = nil
        phase = .asking
        listen()
        player.play(a, from: store)
    }

    private func listen() {
        // all names of the animals in play help the recognizer with unusual words
        let hints = pool.flatMap { [$0.name] + ($0.say ?? []) }
        listener.start(hints: Array(Set(hints)))
    }

    private func evaluate() {
        guard phase == .asking, let round = rounds.last else { return }
        let texts = [listener.transcript] + listener.alternatives
        switch AnswerMatcher.verdict(texts: texts, answer: round.answer, pool: pool) {
        case .correct: reveal(.right)
        case .close: reveal(.close)
        case .wrong(let other):
            withAnimation { wrongGuess = other }
            listen()   // fresh transcript for the next try
        case .none: break
        }
    }

    private func reveal(_ result: Result) {
        guard var round = rounds.popLast() else { return }
        listener.stop()
        round.result = result
        if result == .right || result == .close {
            let seconds = Date().timeIntervalSince(round.started)
            let speed = max(0.3, min(1, 1 - (seconds - 4) / 12 * 0.7))
            round.points = Int(100 * speed) - (result == .close ? 20 : 0) - (wrongGuess == nil ? 0 : 20)
            withAnimation { score += round.points }
        }
        rounds.append(round)
        phase = .revealed
        player.play(round.answer, from: store)
    }
}

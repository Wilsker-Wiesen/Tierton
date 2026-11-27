import SwiftUI

/// Quiz: a sound plays and 10 or 15 animals that sound alike are on offer – all on one screen,
/// no scrolling. Faster answers earn more points.
struct QuizView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player

    struct Round {
        let answer: Animal
        let choices: [Animal]
        var picked: Animal?
        let started = Date()
    }

    static let roundsPerGame = 10
    static let maxPoints = 100
    static let choiceCounts = [10, 15]
    private let accent = Color(hex: "#2F78A8")

    @State private var showNames = true
    @AppStorage("quizChoiceCount") private var choiceCount = 15
    @State private var selected: Set<String> = []
    @State private var birdsOnly = false
    @State private var rounds: [Round] = []
    @State private var score = 0
    @State private var streak = 0
    @State private var lastPoints: Int?
    @State private var finished = false
    @State private var detail: Animal?
    @AppStorage("quizBest") private var best = 0

    var body: some View {
        Group {
            if finished { results }
            else if let round = rounds.last { play(round) }
            else { setup }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { AnimalDetailView(animal: $0) }
        .onDisappear { player.stop() }
    }

    private var pool: [Animal] { store.pool(categories: selected, birdsOnly: birdsOnly) }

    // MARK: Setup

    private var setup: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(accent)
                    .padding(.top, 20)
                Text("Hör genau hin und finde das richtige Tier so schnell wie möglich!")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Auswahl beim Raten").font(.headline).padding(.horizontal)
                    Picker("Auswahl", selection: $choiceCount) {
                        ForEach(Self.choiceCounts, id: \.self) { Text("\($0) ähnliche").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Text("\(choiceCount) Tiere, die ähnlich klingen").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tiere").font(.headline).padding(.horizontal)
                    CategoryFilter(selected: $selected, birdsOnly: $birdsOnly)
                    Text("\(pool.count) Tiere zur Auswahl").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
                }
                Toggle(isOn: $showNames) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Namen anzeigen").font(.headline)
                        Text("Ohne Namen ist es schwerer: nur die Bilder.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                if best > 0 {
                    Label("Rekord: \(best) Punkte", systemImage: "trophy.fill")
                        .font(.headline).foregroundStyle(.orange)
                }
                BigButton(title: "Los geht's", symbol: "play.fill", color: accent) { startGame() }
                    .disabled(pool.count < 2)
                    .padding(.horizontal)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
        .onAppear { if !Self.choiceCounts.contains(choiceCount) { choiceCount = 15 } }
    }

    // MARK: Playing

    private func play(_ round: Round) -> some View {
        let answered = round.picked != nil
        let playing = player.playingID == round.answer.id
        return VStack(spacing: 8) {
            HStack {
                Text("Runde \(rounds.count)/\(Self.roundsPerGame)").font(.headline)
                Spacer()
                if streak >= 2 {
                    Label("\(streak)", systemImage: "flame.fill").foregroundStyle(.orange).font(.headline)
                }
                Text("\(score) Punkte").font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal)
            Button { player.play(round.answer, from: store) } label: {
                Label(playing ? "Hör genau hin …" : "Nochmal hören",
                      systemImage: playing ? "speaker.wave.3.fill" : "arrow.counterclockwise")
                    .font(.headline)
                    .symbolEffect(.variableColor.iterative, isActive: playing)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(accent.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)

            // all choices on one screen: pick the column count that gives the biggest tiles
            GeometryReader { geo in
                let n = round.choices.count, gap: CGFloat = 8
                let (cols, side) = Self.bestGrid(n: n, size: geo.size, gap: gap)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: cols), spacing: gap) {
                    ForEach(round.choices) { a in
                        choiceTile(a, round: round).frame(width: side, height: side)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 6)
        .safeAreaInset(edge: .bottom) {
            if answered {
                feedback(round)
                    .padding()
                    .background(.regularMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Column count and tile side that make `n` square tiles as large as possible inside `size`.
    static func bestGrid(n: Int, size: CGSize, gap: CGFloat) -> (Int, CGFloat) {
        var best = (2, CGFloat(0))
        for cols in 2...6 {
            let rows = (n + cols - 1) / cols
            let side = min((size.width - gap * CGFloat(cols - 1)) / CGFloat(cols),
                           (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows))
            if side > best.1 { best = (cols, side) }
        }
        return (best.0, max(40, floor(best.1)))
    }

    private func choiceTile(_ a: Animal, round: Round) -> some View {
        let answered = round.picked != nil
        let isAnswer = a.id == round.answer.id
        let isPicked = a.id == round.picked?.id
        return AnimalTile(animal: a, showName: showNames || answered, showsPlaying: false)
            .overlay {
                if answered && (isAnswer || isPicked) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isAnswer ? Color.green : Color.red, lineWidth: 5)
                    Image(systemName: isAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, isAnswer ? Color.green : Color.red)
                        .shadow(radius: 4)
                }
            }
            .opacity(answered && !isAnswer && !isPicked ? 0.35 : 1)
            .onTapGesture { if !answered { withAnimation { answer(a) } } }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(a.name)
    }

    @ViewBuilder private func feedback(_ round: Round) -> some View {
        if let picked = round.picked {
            let right = picked.id == round.answer.id
            HStack(spacing: 12) {
                AnimalPhoto(animal: round.answer).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(right ? "Richtig! +\(lastPoints ?? 0)" : "Das war: \(round.answer.name)")
                        .font(.title3.bold())
                        .foregroundStyle(right ? .green : .red)
                    Button("Infos zum Tier") { detail = round.answer }
                        .font(.subheadline)
                }
                Spacer()
                Button {
                    withAnimation { nextRound() }
                } label: {
                    Label(rounds.count == Self.roundsPerGame ? "Ergebnis" : "Weiter", systemImage: "forward.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Results

    private var results: some View {
        let correct = rounds.filter { $0.picked?.id == $0.answer.id }.count
        return ScrollView {
            VStack(spacing: 18) {
                Image(systemName: correct >= 8 ? "trophy.fill" : correct >= 5 ? "star.fill" : "hand.thumbsup.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
                    .padding(.top, 30)
                Text("\(score) Punkte").font(.system(size: 44, weight: .heavy, design: .rounded))
                Text("\(correct) von \(Self.roundsPerGame) richtig").font(.title3)
                if score >= best && score > 0 {
                    Label("Neuer Rekord!", systemImage: "sparkles").font(.headline).foregroundStyle(.orange)
                }
                VStack(spacing: 8) {
                    ForEach(Array(rounds.enumerated()), id: \.offset) { _, r in
                        let right = r.picked?.id == r.answer.id
                        Button { detail = r.answer } label: {
                            HStack {
                                AnimalPhoto(animal: r.answer).frame(width: 52, height: 52)
                                VStack(alignment: .leading) {
                                    Text(r.answer.name).font(.headline)
                                    if !right, let p = r.picked {
                                        Text("getippt: \(p.name)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(right ? .green : .red)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                HStack(spacing: 12) {
                    BigButton(title: "Einstellungen", symbol: "slider.horizontal.3", color: .gray) {
                        rounds = []; finished = false
                    }
                    BigButton(title: "Nochmal", symbol: "arrow.counterclockwise", color: accent) {
                        startGame()
                    }
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
        score = 0; streak = 0; lastPoints = nil; finished = false
        rounds = []
        nextRound()
    }

    private func nextRound() {
        if rounds.count >= Self.roundsPerGame {
            player.stop()
            best = max(best, score)
            finished = true
            return
        }
        let used = Set(rounds.map(\.answer.id))
        guard let answer = (pool.filter { !used.contains($0.id) }.randomElement() ?? pool.randomElement()) else { return }
        let shown = SoundGroups.similar(to: answer, in: pool, count: min(choiceCount, 15))
        rounds.append(Round(answer: answer, choices: shown))
        player.play(answer, from: store)
    }

    private func answer(_ a: Animal) {
        guard var round = rounds.popLast() else { return }
        round.picked = a
        let right = a.id == round.answer.id
        if right {
            let seconds = Date().timeIntervalSince(round.started)
            // 100 points within 4 s, dropping to 30 at 20 s; streak bonus +10 per step (max +50).
            let speed = max(0.3, min(1, 1 - (seconds - 4) / 16 * 0.7))
            let points = Int(Double(Self.maxPoints) * speed) + min(streak, 5) * 10
            streak += 1
            lastPoints = points
            score += points
        } else {
            streak = 0
            lastPoints = 0
        }
        rounds.append(round)
    }
}

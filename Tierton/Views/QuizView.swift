import SwiftUI

/// Quiz: a sound plays, and ALL animals of the selection are on offer – sorted by habitat like in
/// "Entdecken", so you learn where to look instead of guessing by elimination.
/// Faster answers earn more points.
struct QuizView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player

    enum Choices: String, CaseIterable, Identifiable {
        case ten = "10 ähnliche", twenty = "20 ähnliche", all = "Alle Tiere"
        var id: String { rawValue }
        var count: Int? { switch self { case .ten: 10; case .twenty: 20; case .all: nil } }
        var info: String {
            switch self {
            case .ten: "10 Tiere, die ähnlich klingen"
            case .twenty: "20 Tiere, die ähnlich klingen"
            case .all: "Alle Tiere, sortiert nach Lebensraum"
            }
        }
    }

    struct Round {
        let answer: Animal
        let choices: [Animal]   // shown animals (all of the pool in "Alle Tiere" mode)
        var picked: Animal?
        let started = Date()
    }

    static let roundsPerGame = 10
    static let maxPoints = 100
    private let accent = Color(hex: "#2F78A8")

    @State private var showNames = true
    @AppStorage("quizChoices") private var choices: Choices = .twenty
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
                    Picker("Auswahl", selection: $choices) {
                        ForEach(Choices.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Text(choices.info).font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
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
    }

    // MARK: Playing

    private func play(_ round: Round) -> some View {
        let answered = round.picked != nil
        let playing = player.playingID == round.answer.id
        let cats = store.categories.filter { c in round.choices.contains { $0.category == c.id } }
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Runde \(rounds.count)/\(Self.roundsPerGame)").font(.headline)
                        Spacer()
                        if streak >= 2 {
                            Label("\(streak)", systemImage: "flame.fill").foregroundStyle(.orange).font(.headline)
                        }
                        Text("\(score) Punkte").font(.headline.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                    Button { player.play(round.answer, from: store) } label: {
                        Label(playing ? "Hör genau hin …" : "Nochmal hören",
                              systemImage: playing ? "speaker.wave.3.fill" : "arrow.counterclockwise")
                            .font(.headline)
                            .symbolEffect(.variableColor.iterative, isActive: playing)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(accent.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    if choices == .all && cats.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(cats) { c in
                                    Button { withAnimation { proxy.scrollTo("cat-" + c.id, anchor: .top) } } label: {
                                        Label(c.name, systemImage: c.symbol)
                                            .font(.footnote.weight(.semibold))
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .foregroundStyle(c.tint)
                                            .background(c.tint.opacity(0.14), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)

                ScrollView {
                    if choices != .all {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 150), spacing: 8)], spacing: 8) {
                            ForEach(round.choices) { a in choiceTile(a, round: round).id(a.id) }
                        }
                        .padding()
                    } else {
                    LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(cats) { c in
                            Section {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 130), spacing: 8)], spacing: 8) {
                                    ForEach(round.choices.filter { $0.category == c.id }) { a in
                                        choiceTile(a, round: round).id(a.id)
                                    }
                                }
                                .padding(.horizontal)
                            } header: {
                                Label(c.name, systemImage: c.symbol)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(c.tint)
                                    .padding(.horizontal).padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                                    .id("cat-" + c.id)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if answered {
                    feedback(round)
                        .padding()
                        .background(.regularMaterial)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: answered) { _, now in
                // after a wrong answer, show where the right animal is
                if now, round.picked?.id != round.answer.id {
                    withAnimation { proxy.scrollTo(round.answer.id, anchor: .center) }
                }
            }
            .onChange(of: rounds.count) {
                if let first = cats.first { proxy.scrollTo("cat-" + first.id, anchor: .top) }
            }
        }
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
                        .font(.system(size: 34))
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
        let shown = choices.count.map { SoundGroups.similar(to: answer, in: pool, count: $0) } ?? pool
        rounds.append(Round(answer: answer, choices: shown))
        player.play(answer, from: store)
    }

    private func answer(_ a: Animal) {
        guard var round = rounds.popLast() else { return }
        round.picked = a
        let right = a.id == round.answer.id
        if right {
            let seconds = Date().timeIntervalSince(round.started)
            // Searching takes time: 100 points within 5 s, dropping to 30 at 25 s;
            // streak bonus +10 per step (max +50).
            let speed = max(0.3, min(1, 1 - (seconds - 5) / 20 * 0.7))
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

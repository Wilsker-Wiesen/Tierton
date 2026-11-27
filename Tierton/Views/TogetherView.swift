import SwiftUI

/// Guessing game for two (or more): one person plays a sound – chosen at random or picked
/// secretly – and the others guess. Then the animal is revealed.
struct TogetherView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player

    enum Source: String, CaseIterable { case random = "Zufall", pick = "Ich suche aus" }
    enum Phase { case setup, hidden(Animal), revealed(Animal) }

    @State private var source: Source = .random
    @State private var phase: Phase = .setup
    @State private var selected: Set<String> = []
    @State private var birdsOnly = false
    @State private var recent: [String] = []
    @State private var detail: Animal?

    var body: some View {
        Group {
            switch phase {
            case .setup: setup
            case .hidden(let a): hidden(a)
            case .revealed(let a): revealed(a)
            }
        }
        .animation(.snappy, value: phaseKey)
        .navigationTitle("Rätsel zu zweit")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { AnimalDetailView(animal: $0) }
        .onDisappear { player.stop() }
    }

    private var phaseKey: String {
        switch phase {
        case .setup: "s"
        case .hidden(let a): "h" + a.id
        case .revealed(let a): "r" + a.id
        }
    }

    private var pool: [Animal] { store.pool(categories: selected, birdsOnly: birdsOnly) }

    // MARK: Setup

    private var setup: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Wie?", selection: $source) {
                    ForEach(Source.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                CategoryFilter(selected: $selected, birdsOnly: $birdsOnly)
            }
            .padding(.vertical, 10)
            .background(.bar)

            if source == .random {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "questionmark.bubble.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color(hex: "#C0603A"))
                    Text("Drück den Knopf, ein zufälliges Tier ist zu hören. Die anderen raten!")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text("\(pool.count) Tiere in der Auswahl")
                        .font(.subheadline).foregroundStyle(.secondary)
                    BigButton(title: "Geräusch abspielen", symbol: "play.fill", color: Color(hex: "#C0603A")) {
                        startRandom()
                    }
                    .disabled(pool.isEmpty)
                }
                Spacer()
            } else {
                ScrollView {
                    Label("Such dir heimlich ein Tier aus. Die anderen dürfen nicht hinsehen!", systemImage: "eye.slash.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.horizontal)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 170), spacing: 10)], spacing: 10) {
                        ForEach(pool) { a in
                            AnimalTile(animal: a)
                                .onTapGesture { start(a) }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: Hidden

    private func hidden(_ a: Animal) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "#C0603A").opacity(0.15)).frame(width: 220, height: 220)
                Image(systemName: player.playingID == a.id ? "speaker.wave.3.fill" : "questionmark")
                    .font(.system(size: 90, weight: .heavy))
                    .foregroundStyle(Color(hex: "#C0603A"))
                    .symbolEffect(.variableColor.iterative, isActive: player.playingID == a.id)
                    .contentTransition(.symbolEffect(.replace))
            }
            Text("Welches Tier ist das?")
                .font(.largeTitle.bold())
            Spacer()
            HStack(spacing: 12) {
                BigButton(title: "Nochmal", symbol: "arrow.counterclockwise", color: .gray) {
                    player.play(a, from: store)
                }
                BigButton(title: "Auflösen", symbol: "eye.fill", color: Color(hex: "#C0603A")) {
                    phase = .revealed(a)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    // MARK: Revealed

    private func revealed(_ a: Animal) -> some View {
        VStack(spacing: 16) {
            AnimalPhoto(animal: a, circleOpacity: 0.32)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 440, maxHeight: 400)
                .padding(.horizontal)
                .padding(.top)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .onTapGesture { player.toggle(a, from: store) }
            Text(a.name).font(.largeTitle.bold())
            if let c = store.category(of: a) {
                Label(c.name, systemImage: c.symbol).foregroundStyle(c.tint).font(.headline)
            }
            Button { detail = a } label: {
                Label("Mehr über das Tier", systemImage: "info.circle.fill")
            }
            Spacer()
            HStack(spacing: 12) {
                BigButton(title: "Einstellungen", symbol: "slider.horizontal.3", color: .gray) {
                    player.stop(); phase = .setup
                }
                BigButton(title: "Nächstes Tier", symbol: "forward.fill", color: Color(hex: "#C0603A")) {
                    if source == .random { startRandom() } else { player.stop(); phase = .setup }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    // MARK: Logic

    private func startRandom() {
        // Avoid repeating one of the last few animals.
        let fresh = pool.filter { !recent.contains($0.id) }
        guard let a = (fresh.isEmpty ? pool : fresh).randomElement() else { return }
        recent.append(a.id)
        if recent.count > min(15, max(pool.count / 2, 1)) { recent.removeFirst() }
        start(a)
    }

    private func start(_ a: Animal) {
        phase = .hidden(a)
        player.play(a, from: store)
    }
}

struct BigButton: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 12)
                .background(enabled ? color : .gray.opacity(0.4), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 360)
    }
}

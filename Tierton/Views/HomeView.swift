import SwiftUI

enum Mode: Hashable { case explore, together, quiz, voice, credits }

struct HomeView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player
    @State private var path: [Mode] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    ModeCard(title: "Entdecken",
                             text: "Scroll von der Arktis bis zum Südpol. Tippe ein Tier an und hör, wie es klingt.",
                             symbol: "binoculars.fill", color: Color(hex: "#2E8B57")) { path.append(.explore) }
                    ModeCard(title: "Rätsel zu zweit",
                             text: "Einer spielt ein Geräusch ab, der andere rät, welches Tier das war.",
                             symbol: "person.2.fill", color: Color(hex: "#C0603A")) { path.append(.together) }
                    ModeCard(title: "Quiz",
                             text: "Du hörst ein Geräusch – tippe so schnell wie möglich auf das richtige Tier.",
                             symbol: "bolt.fill", color: Color(hex: "#2F78A8")) { path.append(.quiz) }
                    ModeCard(title: "Sag's laut!",
                             text: "Ein Tier ist zu hören, aber nicht zu sehen. Sag einfach laut, welches Tier es ist.",
                             symbol: "mic.fill", color: Color(hex: "#8E5BB5")) { path.append(.voice) }
                    Button { path.append(.credits) } label: {
                        Label("Bild- und Tonnachweise", systemImage: "info.circle")
                            .font(.footnote)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: Mode.self) { mode in
                switch mode {
                case .explore: ExploreView()
                case .together: TogetherView()
                case .quiz: QuizView()
                case .voice: VoiceQuizView()
                case .credits: CreditsView()
                }
            }
            .onChange(of: path) { player.stop() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Tierton")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
            Text("\(store.animals.count) Tiere und ihre Stimmen")
                .font(.headline)
                .foregroundStyle(.secondary)
            mosaic
        }
        .padding(.vertical, 8)
    }

    /// A row of round photos as a friendly header.
    private var mosaic: some View {
        let picks = ["loewe", "eisbaer", "kaiserpinguin", "elefant", "amsel", "delfin", "koala"]
            .compactMap { id in store.animals.first { $0.id == id } }
        return HStack(spacing: -6) {
            ForEach(picks) { a in
                AnimalPhoto(animal: a)
                    .frame(width: 70, height: 70)
            }
        }
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

private struct ModeCard: View {
    let title: String
    let text: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    Text(text).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

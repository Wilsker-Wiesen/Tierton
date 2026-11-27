import SwiftUI

/// Quartet-style info card: photo, sound, stats, IUCN status and a fun fact.
struct AnimalDetailView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    let animal: Animal

    var body: some View {
        let facts = store.facts(for: animal)
        let category = store.category(of: animal)
        let tint = category?.tint ?? .accentColor
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AnimalPhoto(animal: animal, circleOpacity: 0.32)
                        .frame(width: 300, height: 300)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(alignment: .bottomTrailing) { playButton(tint: tint) }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(animal.name).font(.largeTitle.bold())
                        Text(animal.sci).font(.headline).italic().foregroundStyle(.secondary)
                        if let category {
                            Label(category.name, systemImage: category.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tint)
                                .padding(.top, 4)
                        }
                    }

                    if let g = facts?.geraeusch {
                        Label(g, systemImage: "waveform").font(.body.weight(.medium))
                    }

                    if let facts {
                        statsGrid(facts, tint: tint)
                    }

                    if let status = store.status(for: animal) {
                        card(title: "Rote Liste (IUCN)", symbol: "exclamationmark.shield.fill") {
                            ConservationScale(status: status)
                        }
                    }

                    if let fakt = facts?.fakt {
                        card(title: "Schon gewusst?", symbol: "lightbulb.fill") {
                            Text(fakt).font(.body)
                        }
                    }

                    credits
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .onAppear { if player.playingID != animal.id { player.play(animal, from: store) } }
        .onDisappear { player.stop() }
    }

    private func playButton(tint: Color) -> some View {
        let playing = player.playingID == animal.id
        return Button { player.toggle(animal, from: store) } label: {
            Image(systemName: playing ? "stop.fill" : "play.fill")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(tint, in: Circle())
                .shadow(radius: 6)
        }
        .padding(12)
        .accessibilityLabel(playing ? "Stopp" : "Geräusch abspielen")
    }

    private func statsGrid(_ f: AnimalFacts, tint: Color) -> some View {
        let rows: [(String, String, String?)] = [
            ("ruler", "Größe", f.laenge),
            ("scalemass.fill", "Gewicht", f.gewicht),
            ("hourglass", "Alter", f.alter),
            ("speedometer", "Tempo", f.tempo),
            ("figure.and.child.holdinghands", "Nachwuchs", f.nachwuchs),
            ("calendar", "Wie oft", f.wieOft),
            ("clock.fill", "Tragzeit / Brut", f.tragzeit),
            ("fork.knife", "Nahrung", f.nahrung),
            ("map.fill", "Lebensraum", f.lebensraum),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(rows.filter { $0.2 != nil }, id: \.1) { symbol, title, value in
                VStack(alignment: .leading, spacing: 4) {
                    Label(title, systemImage: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(value ?? "")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func card<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var credits: some View {
        if let m = store.media(for: animal) {
            VStack(alignment: .leading, spacing: 4) {
                if let i = m.image { CreditLine(kind: "Foto", credit: i) }
                if let s = m.sound { CreditLine(kind: "Ton", credit: s) }
                Text("Werte sind typische Angaben für erwachsene Tiere und können je nach Quelle abweichen.")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct CreditLine: View {
    let kind: String
    let credit: MediaCredit

    var body: some View {
        let author = credit.artist.flatMap { $0.isEmpty ? nil : $0 } ?? "unbekannt"
        if let url = URL(string: credit.page) {
            Link(destination: url) {
                Text("\(kind)\(credit.edited.map { " (\($0))" } ?? ""): \(author), \(credit.license ?? "freie Lizenz"), via Wikimedia Commons")
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

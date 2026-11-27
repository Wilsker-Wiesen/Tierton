import SwiftUI

/// One continuous scroll through all habitats, from the Arctic to Antarctica.
/// Tap an animal to hear it; the "i" button opens its quartet card.
struct ExploreView: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player
    @State private var birdsOnly = false
    @State private var detail: Animal?
    @State private var visibleCategory: String?

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 190), spacing: 10)]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                    ForEach(store.categories) { category in
                        let animals = store.animals(in: category, birdsOnly: birdsOnly)
                        if !animals.isEmpty {
                            Section {
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(animals) { animal in
                                        AnimalTile(animal: animal, onInfo: { detail = animal })
                                            .onTapGesture { player.toggle(animal, from: store) }
                                            .accessibilityAddTraits(.isButton)
                                            .accessibilityLabel(animal.name)
                                            .accessibilityHint("Spielt das Geräusch ab")
                                    }
                                }
                                .padding(.horizontal)
                            } header: {
                                SectionHeader(category: category)
                                    .id(category.id)
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                jumpBar(proxy: proxy)
            }
        }
        .navigationTitle("Entdecken")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $birdsOnly.animation()) {
                    Label("Nur Vögel", systemImage: "bird.fill")
                }
                .toggleStyle(.button)
                .accessibilityLabel("Nur Vögel anzeigen")
            }
        }
        .sheet(item: $detail) { animal in
            AnimalDetailView(animal: animal)
        }
        .onDisappear { player.stop() }
    }

    /// Horizontal list of habitats to jump to.
    private func jumpBar(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.categories) { c in
                    Button {
                        withAnimation { proxy.scrollTo(c.id, anchor: .top) }
                    } label: {
                        Label(c.name, systemImage: c.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(c.tint)
                            .background(c.tint.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct SectionHeader: View {
    let category: AnimalCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(category.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(category.name).font(.title2.bold())
                Text(category.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .accessibilityAddTraits(.isHeader)
    }
}

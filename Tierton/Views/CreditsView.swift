import SwiftUI

/// Attribution for every photo and sound (required by the CC BY / CC BY-SA licenses).
struct CreditsView: View {
    @Environment(AnimalStore.self) private var store

    var body: some View {
        List {
            Section {
                Text("Alle Fotos und Tonaufnahmen stammen von Wikimedia Commons und stehen unter freien Lizenzen (gemeinfrei, CC0, CC BY oder CC BY-SA). Die Tiere wurden aus den Fotos freigestellt (Hintergrund entfernt) und verkleinert, Tonaufnahmen gekürzt und in der Lautstärke angeglichen. Gefährdungsstatus: IUCN Rote Liste über Wikidata (CC0).")
                    .font(.footnote)
            }
            ForEach(store.categories) { c in
                Section(c.name) {
                    ForEach(store.animals(in: c)) { a in
                        if let m = store.media(for: a) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(a.name).font(.headline)
                                Group {
                                    if let i = m.image { CreditLine(kind: "Foto", credit: i) }
                                    if let s = m.sound { CreditLine(kind: "Ton", credit: s) }
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Nachweise")
    }
}

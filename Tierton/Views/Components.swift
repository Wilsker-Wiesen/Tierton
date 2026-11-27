import SwiftUI

/// The shared look of every animal: a cut-out animal standing in a soft circle in its habitat
/// colour. Below the circle's centre line the animal is clipped to the circle, above it the head
/// and back "peek out" freely.
struct AnimalPhoto: View {
    @Environment(AnimalStore.self) private var store
    let animal: Animal
    var circleOpacity: Double = 0.28

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let d = min(w * 0.84, h * 0.84)
            let circle = CGRect(x: (w - d) / 2, y: h * 0.97 - d, width: d, height: d)
            let tint = store.category(of: animal)?.tint ?? .accentColor
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(tint.opacity(circleOpacity))
                    .frame(width: d, height: d)
                    .offset(x: circle.minX, y: circle.minY)
                if let img = store.image(for: animal) {
                    let p = PopOutLayout(size: geo.size, circle: circle, image: img.size)
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: p.frame.width, height: p.frame.height)
                        .offset(x: p.frame.minX, y: p.frame.minY)
                        .frame(width: w, height: h, alignment: .topLeading)
                        .clipShape(PopOutShape(circle: circle))
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: d * 0.35))
                        .foregroundStyle(tint)
                        .frame(width: w, height: h)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }
}

/// Where the cut-out goes. Tall/square animals stand on the bottom of the circle and their head
/// sticks out at the top. Wide animals (whales, crocodiles, lying lions) would end up small and low,
/// so they are drawn bigger and centred slightly above the circle's centre – they still peek out.
struct PopOutLayout {
    let frame: CGRect

    init(size: CGSize, circle: CGRect, image: CGSize) {
        let w = size.width, h = size.height, d = circle.width
        let aspect = image.width / max(image.height, 1)
        if aspect > 1.25 {
            let iw = w * 1.0
            let ih = min(iw / aspect, h * 0.9)
            let iw2 = ih * aspect
            let cy = circle.midY - d * 0.06
            let bottom = min(circle.maxY - d * 0.05, cy + ih / 2)
            frame = CGRect(x: (w - iw2) / 2, y: bottom - ih, width: iw2, height: ih)
        } else {
            let box = CGSize(width: w * 0.92, height: h * 0.95)
            let s = min(box.width / image.width, box.height / image.height)
            let iw = image.width * s, ih = image.height * s
            frame = CGRect(x: (w - iw) / 2, y: circle.maxY - d * 0.05 - ih, width: iw, height: ih)
        }
    }
}

/// Circle plus everything above the circle's centre line.
struct PopOutShape: Shape {
    let circle: CGRect

    func path(in rect: CGRect) -> Path {
        var p = Path(ellipseIn: circle)
        p.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: circle.midY - rect.minY))
        return p
    }
}

/// A tile with the pop-out animal and its name, used in the explore grid, pickers and the quiz.
struct AnimalTile: View {
    @Environment(AnimalStore.self) private var store
    @Environment(SoundPlayer.self) private var player
    let animal: Animal
    var showName = true
    var onInfo: (() -> Void)? = nil
    /// false in games: highlighting the playing animal would give the answer away
    var showsPlaying = true

    var body: some View {
        let playing = showsPlaying && player.playingID == animal.id
        let tint = store.category(of: animal)?.tint ?? .accentColor
        VStack(spacing: 2) {
            AnimalPhoto(animal: animal, circleOpacity: playing ? 0.55 : 0.28)
                .aspectRatio(1, contentMode: .fit)
            if showName || onInfo != nil {
                HStack(spacing: 4) {
                    if showName {
                        // single words shrink instead of being hyphenated ("Papageitaucher")
                        let oneWord = !animal.name.contains(" ")
                        Text(animal.name)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(oneWord ? 1 : 2)
                            .minimumScaleFactor(oneWord ? 0.45 : 0.75)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    if let onInfo {
                        Button(action: onInfo) {
                            Image(systemName: "info")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(tint)
                                .frame(width: 26, height: 26)
                                .background(tint.opacity(0.15), in: Circle())
                                .contentShape(Circle().inset(by: -8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Infos zu \(animal.name)")
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, showName ? 8 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topLeading) {
            if playing {
                Image(systemName: "speaker.wave.2.fill")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(tint, in: Circle())
                    .padding(6)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint, lineWidth: playing ? 3 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .scaleEffect(playing ? 0.97 : 1)
        .animation(.spring(duration: 0.25), value: playing)
    }
}

/// Five-step IUCN scale like on the Red List: LC NT VU EN CR.
struct ConservationScale: View {
    let status: ConservationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array([ConservationStatus.LC, .NT, .VU, .EN, .CR].enumerated()), id: \.offset) { i, s in
                    let active = status.level == i
                    Text(s.rawValue)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(active ? .white : s.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(active ? s.color : s.color.opacity(0.15), in: Capsule())
                        .scaleEffect(active ? 1.08 : 1)
                }
            }
            Text(status.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gefährdung: \(status.label)")
    }
}

/// Lets the user pick which categories (and optionally birds only) a game uses.
struct CategoryFilter: View {
    @Environment(AnimalStore.self) private var store
    @Binding var selected: Set<String>
    @Binding var birdsOnly: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Alle", symbol: "globe.europe.africa.fill", color: .accentColor, on: selected.isEmpty) {
                    selected.removeAll()
                }
                chip("Nur Vögel", symbol: "bird.fill", color: Color(hex: "#8E5BB5"), on: birdsOnly) {
                    birdsOnly.toggle()
                }
                ForEach(store.categories) { c in
                    chip(c.name, symbol: c.symbol, color: c.tint, on: selected.contains(c.id)) {
                        if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(_ title: String, symbol: String, color: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(on ? .white : color)
                .background(on ? color : color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension AnimalStore {
    /// Animals matching a category selection (empty = all) and the birds-only switch.
    func pool(categories selected: Set<String>, birdsOnly: Bool) -> [Animal] {
        animals.filter { (selected.isEmpty || selected.contains($0.category)) && (!birdsOnly || $0.isBird) }
    }
}

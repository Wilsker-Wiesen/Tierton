import SwiftUI

struct AnimalCategory: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let color: String

    var tint: Color { Color(hex: color) }
}

struct Animal: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let category: String
    let sci: String
    let bird: Bool?
    /// Other words that count as this animal in the voice game ("Delphin", "Rind", "Pinguin" …).
    let say: [String]?
    /// Sound group for "similar sounding" quiz choices (zwitschern, bruellen, heulen …)
    let klang: String?
    /// hidden animals stay in the catalog but don't appear in the app
    let hidden: Bool?

    var isBird: Bool { bird ?? false }
}

struct AnimalFacts: Decodable, Hashable {
    let laenge: String?
    let gewicht: String?
    let alter: String?
    let nachwuchs: String?
    let wieOft: String?
    let tragzeit: String?
    let nahrung: String?
    let lebensraum: String?
    let tempo: String?
    let geraeusch: String?
    let fakt: String?
}

struct MediaCredit: Decodable, Hashable {
    let title: String
    let artist: String?
    let license: String?
    let licenseUrl: String?
    let page: String
    /// e.g. "freigestellt" when the photo was cut out
    let edited: String?

    /// Commons file name without the "File:" prefix and extension.
    var displayTitle: String {
        var t = title
        if t.hasPrefix("File:") { t.removeFirst(5) }
        return (t as NSString).deletingPathExtension
    }
}

struct AnimalMedia: Decodable, Hashable {
    let iucn: String?
    let wikidata: String?
    let image: MediaCredit?
    let sound: MediaCredit?
}

/// IUCN Red List categories, ordered from safe to extinct.
enum ConservationStatus: String, CaseIterable {
    case LC, NT, VU, EN, CR, EW, EX, DD

    var label: String {
        switch self {
        case .LC: "Nicht gefährdet"
        case .NT: "Potenziell gefährdet"
        case .VU: "Gefährdet"
        case .EN: "Stark gefährdet"
        case .CR: "Vom Aussterben bedroht"
        case .EW: "In der Natur ausgestorben"
        case .EX: "Ausgestorben"
        case .DD: "Unzureichende Datenlage"
        }
    }

    /// Position on the scale 0...4 (LC...CR); nil for categories outside the scale.
    var level: Int? {
        switch self {
        case .LC: 0
        case .NT: 1
        case .VU: 2
        case .EN: 3
        case .CR, .EW, .EX: 4
        case .DD: nil
        }
    }

    var color: Color {
        switch self {
        case .LC: Color(hex: "#3E9B4F")
        case .NT: Color(hex: "#8DB43B")
        case .VU: Color(hex: "#E2B12C")
        case .EN: Color(hex: "#E07A27")
        case .CR, .EW, .EX: Color(hex: "#D23B32")
        case .DD: .gray
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// Which sound groups resemble each other – used to pick tricky quiz choices.
enum SoundGroups {
    static let neighbours: [String: [String]] = [
        "zwitschern": ["kreischen", "rufen", "zirpen"],
        "kreischen": ["zwitschern", "rufen", "wasservogel"],
        "rufen": ["kreischen", "wasservogel", "zwitschern"],
        "wasservogel": ["rufen", "kreischen", "meer"],
        "bruellen": ["heulen", "grunzen", "affen"],
        "heulen": ["bruellen", "affen", "blöken"],
        "blöken": ["grunzen", "heulen", "bruellen"],
        "grunzen": ["blöken", "bruellen", "meer"],
        "affen": ["bruellen", "heulen", "kreischen"],
        "meer": ["wasservogel", "grunzen", "bruellen"],
        "zirpen": ["zwitschern", "rufen", "grunzen"],
    ]

    /// `count` animals from `pool` (answer included) that sound most like `answer`, shuffled.
    static func similar(to answer: Animal, in pool: [Animal], count: Int) -> [Animal] {
        let others = pool.filter { $0.id != answer.id }
        let g = answer.klang ?? ""
        var order: [Animal] = others.filter { $0.klang == g }.shuffled()
        for n in neighbours[g] ?? [] { order += others.filter { $0.klang == n }.shuffled() }
        order += others.filter { a in !order.contains(where: { $0.id == a.id }) }.shuffled()
        return (Array(order.prefix(max(0, count - 1))) + [answer]).shuffled()
    }
}

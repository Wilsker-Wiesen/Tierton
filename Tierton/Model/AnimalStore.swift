import SwiftUI
import UIKit

/// Loads the bundled catalog (animals, categories), quartet facts and media credits.
/// Only animals that actually have a sound file are shown in the app.
@Observable
final class AnimalStore {
    let categories: [AnimalCategory]
    let animals: [Animal]
    private let facts: [String: AnimalFacts]
    private let media: [String: AnimalMedia]
    private let categoryByID: [String: AnimalCategory]

    init(bundle: Bundle = .main) {
        struct Catalog: Decodable { let categories: [AnimalCategory]; let animals: [Animal] }
        func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            do { return try JSONDecoder().decode(T.self, from: data) } catch {
                print("Tierton: could not decode \(name).json: \(error)")
                return nil
            }
        }
        let catalog = load("catalog", as: Catalog.self) ?? Catalog(categories: [], animals: [])
        facts = load("facts", as: [String: AnimalFacts].self) ?? [:]
        media = load("media", as: [String: AnimalMedia].self) ?? [:]
        let playable = catalog.animals.filter { $0.hidden != true && bundle.url(forResource: $0.id, withExtension: "m4a", subdirectory: "Media") != nil }
        animals = playable
        let used = Set(playable.map(\.category))
        categories = catalog.categories.filter { used.contains($0.id) }
        categoryByID = Dictionary(uniqueKeysWithValues: catalog.categories.map { ($0.id, $0) })
    }

    func animals(in category: AnimalCategory, birdsOnly: Bool = false) -> [Animal] {
        animals.filter { $0.category == category.id && (!birdsOnly || $0.isBird) }
    }

    func category(of animal: Animal) -> AnimalCategory? { categoryByID[animal.category] }
    func facts(for animal: Animal) -> AnimalFacts? { facts[animal.id] }
    func media(for animal: Animal) -> AnimalMedia? { media[animal.id] }
    func status(for animal: Animal) -> ConservationStatus? {
        media[animal.id]?.iucn.flatMap(ConservationStatus.init(rawValue:))
    }

    func soundURL(for animal: Animal) -> URL? {
        Bundle.main.url(forResource: animal.id, withExtension: "m4a", subdirectory: "Media")
    }

    // MARK: Images

    private let imageCache = NSCache<NSString, UIImage>()

    func image(for animal: Animal) -> UIImage? {
        if let img = imageCache.object(forKey: animal.id as NSString) { return img }
        // Cut-out animals (transparent HEIC); plain JPG as fallback for hand-added animals.
        guard let url = Bundle.main.url(forResource: animal.id, withExtension: "heic", subdirectory: "Media")
                ?? Bundle.main.url(forResource: animal.id, withExtension: "jpg", subdirectory: "Media"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache.setObject(img, forKey: animal.id as NSString)
        return img
    }
}

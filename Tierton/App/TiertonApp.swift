import SwiftUI

@main
struct TiertonApp: App {
    @State private var store = AnimalStore()
    @State private var player = SoundPlayer()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .environment(player)
                .fontDesign(.rounded)
        }
    }
}

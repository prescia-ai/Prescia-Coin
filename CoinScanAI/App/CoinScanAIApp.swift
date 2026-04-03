import SwiftUI

@main
struct CoinScanAIApp: App {
    @StateObject private var collectionManager = CollectionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(collectionManager)
        }
    }
}

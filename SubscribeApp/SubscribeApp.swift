import SwiftUI

@main
struct SubscribeApp: App {
    @StateObject private var store = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
    }
}

import AppKit
import SwiftUI

@main
struct AniAngliaApp: App {
    @StateObject private var authStore: AuthStore
    @StateObject private var imageCache = ImageCache()
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    private let api: AnixartAPI

    init() {
        NSApp.setActivationPolicy(.regular)
        let store = AuthStore()
        _authStore = StateObject(wrappedValue: store)
        api = AnixartAPI(authSessionProvider: { store.currentSession })
    }

    var body: some Scene {
        WindowGroup("AniAnglia") {
            ContentView()
                .environment(\.anixartAPI, api)
                .environmentObject(authStore)
                .environmentObject(imageCache)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                .frame(minWidth: 1024, minHeight: 680)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(authStore)
                .environmentObject(imageCache)
                .frame(width: 520)
        }
    }
}

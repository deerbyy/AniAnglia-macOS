import SwiftUI
import AppKit

@main
struct AniAngliaApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("О программе AniAnglia") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "AniAnglia",
                        .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2",
                        .credits: NSAttributedString(
                            string: "Неофициальный клиент Anixart для macOS.",
                            attributes: [.foregroundColor: NSColor.labelColor]
                        )
                    ])
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 520, height: 420)
        }
    }
}

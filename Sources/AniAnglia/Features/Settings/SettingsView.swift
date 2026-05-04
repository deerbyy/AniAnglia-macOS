import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredVideoQuality") private var preferredQuality: String = "auto"
    @AppStorage("autoNextEpisode") private var autoNext: Bool = true

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Основные", systemImage: "gear") }

            playbackTab
                .tabItem { Label("Воспроизведение", systemImage: "play.rectangle") }

            aboutTab
                .tabItem { Label("О программе", systemImage: "info.circle") }
        }
        .padding()
    }

    private var generalTab: some View {
        Form {
            Section("Кэш") {
                Button("Очистить кэш изображений") {
                    // TODO: hook into RemoteImageCache.shared
                }
            }
            Section("Внешний вид") {
                Text("Тема следует системной (светлая/тёмная) автоматически.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playbackTab: some View {
        Form {
            Section("Видео") {
                Picker("Качество", selection: $preferredQuality) {
                    Text("Авто").tag("auto")
                    Text("360p").tag("360p")
                    Text("480p").tag("480p")
                    Text("720p").tag("720p")
                    Text("1080p").tag("1080p")
                }
                Toggle("Автопереход к следующей серии", isOn: $autoNext)
            }
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.tv")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("AniAnglia")
                .font(.title2.bold())
            if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Версия \(v)")
                    .foregroundStyle(.secondary)
            }
            Text("Неофициальный клиент Anixart для macOS. Использует публичное API api.anixart.tv.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Link("Источник: api.anixart.tv", destination: URL(string: "https://anixart.tv")!)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

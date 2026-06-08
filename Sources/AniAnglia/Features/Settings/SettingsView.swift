import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
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

    @State private var cacheCleared = false

    private var generalTab: some View {
        Form {
            accountDataSection
            Section("Кэш") {
                HStack {
                    Button("Очистить кэш изображений") {
                        RemoteImageCache.shared.clear()
                        cacheCleared = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            cacheCleared = false
                        }
                    }
                    if cacheCleared {
                        Text("Очищено")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
            }
            Section("Внешний вид") {
                Text("Тема следует системной (светлая/тёмная) автоматически.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var accountDataSection: some View {
        Section("Данные аккаунта") {
            if appState.auth.isAuthenticated {
                let counts = appState.bookmarkSync.libraryCounts
                HStack {
                    Button {
                        Task {
                            await appState.bookmarkSync.syncAll(api: appState.api, force: true)
                        }
                    } label: {
                        Label("Синхронизировать библиотеку", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(appState.bookmarkSync.isSyncing)

                    if appState.bookmarkSync.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                LabeledContent("Последняя синхронизация") {
                    Text(lastLibrarySyncText)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Избранное") {
                    Text("\(counts.favoriteReleases)")
                        .monospacedDigit()
                }
                LabeledContent("Коллекции") {
                    Text("\(counts.favoriteCollections)")
                        .monospacedDigit()
                }
                LabeledContent("В списках") {
                    Text("\(counts.totalListedReleases)")
                        .monospacedDigit()
                }
            } else {
                Text("Войди в аккаунт Anixart, чтобы синхронизировать закладки, избранное, коллекции и списки.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastLibrarySyncText: String {
        if let syncedAt = appState.bookmarkSync.lastSyncedAt {
            return syncedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Ещё не запускалась"
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

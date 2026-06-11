import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var imageCache: ImageCache
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("defaultVideoQuality") private var defaultVideoQuality = "auto"
    @AppStorage("skipOpening") private var skipOpening = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var helpPage: HelpPage?

    var body: some View {
        Form {
            Section("Внешний вид") {
                Picker("Тема", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Уведомления") {
                Toggle("Уведомления macOS", isOn: $notificationsEnabled)
                Text("Системная интеграция уведомлений оставлена как заготовка для следующего релиза.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Управление данными") {
                Button {
                    imageCache.clear()
                } label: {
                    Label("Очистить кеш изображений", systemImage: "trash")
                }
            }

            Section("Воспроизведение") {
                Picker("Качество по умолчанию", selection: $defaultVideoQuality) {
                    Text("Авто").tag("auto")
                    Text("1080p").tag("1080")
                    Text("720p").tag("720")
                    Text("480p").tag("480")
                }
                Toggle("Пропускать опенинг", isOn: $skipOpening)
            }

            Section("Помощь") {
                Button {
                    helpPage = HelpPage(title: "FAQ", url: URL(string: "https://anixart.tv/faq")!)
                } label: {
                    Label("FAQ", systemImage: "questionmark.circle")
                }
                Button {
                    helpPage = HelpPage(title: "Правила", url: URL(string: "https://anixart.tv/rules")!)
                } label: {
                    Label("Правила", systemImage: "doc.text")
                }
            }

            Section("Профиль") {
                if authStore.isAuthenticated {
                    Button(role: .destructive) {
                        authStore.signOut()
                    } label: {
                        Label("Выйти из профиля", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Text("Сейчас используется анонимный режим.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .sheet(item: $helpPage) { page in
            VStack(spacing: 0) {
                HStack {
                    Text(page.title)
                        .font(.headline)
                    Spacer()
                    Link(destination: page.url) {
                        Label("Открыть", systemImage: "safari")
                    }
                }
                .padding()
                WebVideoPlayer(url: page.url)
                    .frame(minWidth: 820, minHeight: 620)
            }
        }
    }
}

private struct HelpPage: Identifiable {
    let title: String
    let url: URL
    var id: String { url.absoluteString }
}

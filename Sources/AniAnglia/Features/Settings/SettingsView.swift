import SwiftUI

struct SettingsView: View {
    @ObservedObject private var player = PlayerSettings.shared
    @AppStorage("endpointUrl") private var endpointUrl: String = "api.anixart.tv"
    @State private var cacheCleared = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Основные", systemImage: "gear") }

            playbackTab
                .tabItem { Label("Плеер", systemImage: "play.rectangle") }

            upscaleTab
                .tabItem { Label("Anime4K", systemImage: "sparkles.rectangle.stack") }

            hotkeysTab
                .tabItem { Label("Горячие клавиши", systemImage: "keyboard") }

            aboutTab
                .tabItem { Label("О программе", systemImage: "info.circle") }
        }
        .padding()
    }

    private var generalTab: some View {
        Form {
            Section("Сервер (как в AniDesk endpointUrl)") {
                Picker("API сервер", selection: $endpointUrl) {
                    ForEach(AniDeskUtils.endpointValues, id: \.value) { item in
                        Text(item.label).tag(item.value)
                    }
                }
                .help("api-s.anixsekai.com — зеркало, api.anixart.app — основной, api.anixart.tv — заблокирован в РФ")
                Text("Текущий: https://\(endpointUrl)").font(.caption2).foregroundStyle(.secondary)
                Text("Смена применяется сразу для новых запросов. Если не грузит — попробуй другое зеркало.").font(.caption2).foregroundStyle(.tertiary)
            }
            Section("Кэш") {
                HStack {
                    Button("Очистить кэш изображений") {
                        RemoteImageCache.shared.clear()
                        cacheCleared = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { cacheCleared = false }
                    }
                    if cacheCleared {
                        Text("Очищено").font(.caption).foregroundStyle(.secondary).transition(.opacity)
                    }
                }
            }
            Section("Внешний вид") {
                Text("Тема следует системной (светлая/тёмная) автоматически.").foregroundStyle(.secondary)
            }
            Section("Приватность") {
                Toggle("Не сохранять историю просмотра", isOn: $player.disableHistory)
                    .help("Как в AniDesk playingDefaultSettings.disableHistory")
            }
        }
    }

    private var playbackTab: some View {
        Form {
            Section("Источник и качество (как в AniDesk)") {
                Picker("Источник по умолчанию", selection: $player.defaultSourceRaw) {
                    ForEach(PlayerSettings.sourceValues, id: \.value) { item in Text(item.label).tag(item.value) }
                }.help("Kodik / Libria / Sibnet / Авто — как в AniDesk sourceValues")
                Picker("Качество по умолчанию", selection: $player.defaultQuality) {
                    Text("Авто").tag(0)
                    ForEach(PlayerSettings.qualityValues, id: \.value) { item in Text(item.label).tag(item.value) }
                }
                Picker("Соотношение сторон", selection: $player.defaultAspectRatio) {
                    ForEach(PlayerSettings.aspectRatioValues, id: \.value) { item in Text(item.label).tag(item.value) }
                }
                Picker("Скорость", selection: $player.playbackSpeed) {
                    ForEach(PlayerSettings.playerSpeedValues, id: \.value) { item in Text(item.label).tag(item.value) }
                }
                Toggle("Автопереход к следующей серии", isOn: $player.autoplayEpisode)
                    .help("playerDefaultSettings.autoplayEpisode")
            }
            Section("Звук") {
                HStack {
                    Text("Громкость по умолчанию")
                    Slider(value: $player.defaultVolume, in: 0...1).frame(width: 160)
                    Text("\(Int(player.defaultVolume*100))%").font(.caption2).monospacedDigit().frame(width: 35)
                }
                Toggle("Запоминать громкость", isOn: $player.saveUserVolumeEnabled)
                    .help("playerDefaultSettings.saveUserVolume.enabled")
                HStack {
                    Text("Прозрачность интерфейса")
                    Slider(value: $player.opacityInterface, in: 0...1).frame(width: 160)
                    Text("\(Int(player.opacityInterface*100))%").font(.caption2)
                }
            }
        }
    }

    private var upscaleTab: some View {
        Form {
            Section("Anime4K — улучшение как в AniDesk") {
                Toggle(isOn: $player.upscaleEnabled) {
                    Label("Включить Anime4K", systemImage: "wand.and.stars")
                }
                Picker("Режим", selection: $player.upscaleMode) {
                    ForEach(PlayerSettings.upscaleValues, id: \.value) { item in
                        Text(item.label).tag(item.value)
                    }
                }
                .help("Выбор как в AniDesk utils.ts upscaleValues — ModeB по умолчанию")
                if let cur = PlayerSettings.upscaleValues.first(where: { $0.value == player.upscaleMode }) {
                    Text(cur.description).font(.caption2).foregroundStyle(.secondary)
                }
                Text("На macOS 14+ с WebGPU — нативный GPU-апскейл через anime4k-webgpu. На macOS 13 — мягкий CSS-фолбэк (contrast/saturate). В плеере переключение на лету без перезагрузки.").font(.caption2).foregroundStyle(.secondary)
            }
            Section {
                Text("Рекомендация из AniDesk: ModeB (15) — баланс скорости и детализации, ModeC (16) — максимум качества, CNNx2M (8) — быстрый 2x.").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var hotkeysTab: some View {
        Form {
            Section("Горячие клавиши (как в AniDesk hotkeys)") {
                LabeledContent("Пауза/Пуск", value: "Space")
                LabeledContent("Вперёд 10с", value: "→")
                LabeledContent("Назад 10с", value: "←")
                LabeledContent("Мьют", value: "M")
                LabeledContent("Фуллскрин", value: "F")
                LabeledContent("След. серия", value: "N")
                LabeledContent("Пред. серия", value: "B")
                LabeledContent("Пропуск опенинга 85с", value: "S")
                LabeledContent("Закрыть плеер", value: "Esc")
            }
            Section {
                Text("Работают когда плеер открыт и фокус не в поле ввода. Также доступны кнопки в плеере.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.tv").font(.system(size: 56)).foregroundStyle(.tint)
            Text("AniAnglia").font(.title2.bold())
            if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Версия \(v)").foregroundStyle(.secondary)
            }
            Text("Неофициальный клиент Anixart для macOS. Адаптирован плеер из AniDesk (Anixart-PC) — Anime4K, источники Kodik/Sibnet, горячие клавиши.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 40)
            Link("Anixart API: api.anixart.tv", destination: URL(string: "https://api.anixart.tv")!)
            Link("Исходник PC: GhostQut/Anixart-PC", destination: URL(string: "https://github.com/GhostQut/Anixart-PC")!)
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Сборка \(build)").font(.caption2).foregroundStyle(.tertiary)
            }
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

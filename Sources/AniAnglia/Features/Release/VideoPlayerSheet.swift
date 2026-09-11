import SwiftUI
import WebKit
import AppKit

// MARK: - Адаптированный плеер из AniDesk (Anixart-PC) под macOS
// Фишки из AniDesk: Anime4K (WebGPU), выбор источника/качества/скорости/соотношения, громкость, hotkeys, Sibnet-парсер, User-Agent AnixartApp

struct VideoPlayerSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = PlayerSettings.shared
    @State private var showSettings = false
    @State private var resolvedURL: URL?
    @State private var isResolving = false
    @State private var errorText: String?

    // Для горячих клавиш — показываем подсказку
    @State private var lastHotkey: String?
    @State private var hotkeyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title ?? "Видео")
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let host = video.hosting?.name {
                            Text(host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if settings.upscaleEnabled {
                            Label("Anime4K Mode \(settings.upscaleMode)", systemImage: "wand.and.stars")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                }
                Spacer()
                Button { showSettings.toggle() } label: {
                    Label("Настройки плеера", systemImage: "slider.horizontal.3")
                }
                .help("Настройки плеера (Kodik/Sibnet, качество, Anime4K, скорость)")
                .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                    playerSettingsPopover
                        .frame(width: 340)
                        .padding()
                }
                if let url = video.resolvedPlayerURL {
                    Link(destination: url) {
                        Label("В браузере", systemImage: "safari")
                    }
                    .padding(.trailing, 8)
                }
                Button(role: .cancel) { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Закрыть (Esc)")
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            // Быстрые контролы как в AniDesk utils.ts sourceValues/qualityValues
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Источник
                    Picker("Источник", selection: $settings.defaultSourceRaw) {
                        ForEach(PlayerSettings.sourceValues, id: \.value) { item in
                            Text(item.label).tag(item.value)
                        }
                    }.frame(width: 130)
                    .onChange(of: settings.defaultSourceRaw) { _ in Task { await resolveIfNeeded(force: true) } }

                    Divider().frame(height: 20)

                    // Качество
                    Picker("Качество", selection: $settings.defaultQuality) {
                        Text("Авто").tag(0)
                        ForEach(PlayerSettings.qualityValues, id: \.value) { item in
                            Text(item.label).tag(item.value)
                        }
                    }.frame(width: 110)

                    // Скорость
                    Picker("Скорость", selection: $settings.playbackSpeed) {
                        ForEach(PlayerSettings.playerSpeedValues, id: \.value) { item in
                            Text(item.label).tag(item.value)
                        }
                    }.frame(width: 90)

                    // Соотношение
                    Picker("Экран", selection: $settings.defaultAspectRatio) {
                        ForEach(PlayerSettings.aspectRatioValues, id: \.value) { item in
                            Text(item.label).tag(item.value)
                        }
                    }.frame(width: 100)

                    Divider().frame(height: 20)

                    // Громкость
                    HStack(spacing: 6) {
                        Image(systemName: settings.effectiveVolume == 0 ? "speaker.slash" : "speaker.wave.2")
                        Slider(value: Binding(
                            get: { settings.effectiveVolume },
                            set: { newVal in
                                settings.saveVolume(newVal)
                                // Применим через JS без перезагрузки
                                NotificationCenter.default.post(name: .playerVolumeChanged, object: newVal)
                            }), in: 0...1)
                            .frame(width: 80)
                        Text("\(Int(settings.effectiveVolume*100))%").font(.caption2).monospacedDigit().frame(width: 30)
                    }

                    Divider().frame(height: 20)

                    // Anime4K
                    Toggle(isOn: $settings.upscaleEnabled) {
                        Label("Anime4K", systemImage: "sparkles.rectangle.stack")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Улучшение качества как в AniDesk. Требует WebGPU (macOS 14+), иначе CSS-фолбэк.")

                    if settings.upscaleEnabled {
                        Picker("", selection: $settings.upscaleMode) {
                            ForEach(PlayerSettings.upscaleValues, id: \.value) { item in
                                Text(item.label.replacingOccurrences(of: " [Preset]", with: "")).tag(item.value)
                            }
                        }
                        .frame(width: 120)
                        .help(PlayerSettings.upscaleValues.first(where: { $0.value == settings.upscaleMode })?.description ?? "")
                    }

                    Button { NotificationCenter.default.post(name: .playerFullscreen, object: nil) } label: {
                        Label("Фуллскрин", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .help("F — фуллскрин, M — мьют, Space — пауза, ←→ — перемотка 10с")
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(.bar)

            Divider()

            if isResolving {
                VStack(spacing: 12) {
                    ProgressView("Паршу Sibnet…")
                    Text("Извлекаю прямую ссылку как в AniDesk").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let url = resolvedURL {
                ZStack(alignment: .bottom) {
                    WebView(
                        url: url,
                        quality: settings.defaultQuality,
                        speed: settings.playbackSpeed,
                        volume: settings.effectiveVolume,
                        aspectRatio: settings.defaultAspectRatio,
                        upscaleEnabled: settings.upscaleEnabled,
                        upscaleMode: settings.upscaleMode
                    )
                    // Hotkey toast
                    if let hk = lastHotkey {
                        Text(hk)
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 20)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            } else if let err = errorText {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Ошибка").font(.headline)
                    Text(err).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Нет URL для воспроизведения")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Подсказка по горячим клавишам из AniDesk hotkeys
            HStack(spacing: 12) {
                Label("Space пауза", systemImage: "pause.fill").font(.caption2)
                Label("← → 10с", systemImage: "arrow.left.arrow.right").font(.caption2)
                Label("M мьют", systemImage: "speaker.slash").font(.caption2)
                Label("F фуллскрин", systemImage: "arrow.up.left.and.arrow.down.right").font(.caption2)
                Label("N/B след/пред", systemImage: "chevron.left.forwardslash.chevron.right").font(.caption2)
                Spacer()
                if settings.saveUserVolumeEnabled { Text("Громкость сохраняется").font(.caption2).foregroundStyle(.secondary) }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.bar)
        }
        .frame(minWidth: 900, minHeight: 600)
        .task { await resolveIfNeeded() }
        .onAppear {
            hotkeyMonitor = installHotkeys()
        }
        .onDisappear {
            if let m = hotkeyMonitor { NSEvent.removeMonitor(m); hotkeyMonitor = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerHotkeyToast)) { n in
            if let t = n.object as? String {
                withAnimation { lastHotkey = t }
                DispatchQueue.main.asyncAfter(deadline: .now()+1.2) { withAnimation { lastHotkey = nil } }
            }
        }
    }

    // MARK: - Поповер настроек (расширенный как в AniDesk)
    private var playerSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройки плеера (как в AniDesk)").font(.headline)
            Divider()
            Toggle("Автовоспроизведение следующей серии", isOn: $settings.autoplayEpisode)
            Toggle("Запоминать громкость", isOn: $settings.saveUserVolumeEnabled)
            Toggle("Не сохранять историю просмотра", isOn: $settings.disableHistory)
            HStack {
                Text("Прозрачность интерфейса")
                Slider(value: $settings.opacityInterface, in: 0...1).frame(width: 120)
                Text("\(Int(settings.opacityInterface*100))%").font(.caption2)
            }
            Text("Источник по умолчанию влияет на выбор блока видео, если их несколько (Kodik/Sibnet/Libria). Качество и скорость применяются ко всем <video> через JS без перезагрузки.").font(.caption2).foregroundStyle(.secondary)
            Divider()
            Text("Anime4K: \(PlayerSettings.upscaleValues.first(where: {$0.value==settings.upscaleMode})?.description ?? "")").font(.caption2).foregroundStyle(.secondary)
            if !settings.upscaleEnabled {
                Text("Включи Anime4K для апскейла. На macOS 14+ с WebGPU — нативный GPU-апскейл, на macOS 13 — мягкий CSS-фолбэк.").font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Sibnet парсинг как в AniDesk (sibnet:parse)
    private func resolveIfNeeded(force: Bool = false) async {
        if resolvedURL != nil && !force { return }
        guard let base = video.resolvedPlayerURL else { resolvedURL = nil; return }
        // Если Sibnet и выбран парсинг — пробуем достать прямую ссылку
        let host = base.host ?? ""
        let isSibnet = host.contains("sibnet") || (video.hosting?.name?.lowercased().contains("sibnet") ?? false)
        if isSibnet {
            isResolving = true
            defer { isResolving = false }
            do {
                let direct = try await SibnetParser.directLink(for: base)
                await MainActor.run { resolvedURL = direct }
            } catch {
                await MainActor.run { errorText = "Sibnet: не удалось извлечь прямую ссылку: \(error.localizedDescription)"; resolvedURL = base }
            }
        } else {
            resolvedURL = base
        }
    }

    // MARK: - Hotkeys (из AniDesk utils hotkeys)
    private func installHotkeys() -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Не мешаем вводу в текстовых полях
            if let win = NSApp.keyWindow, win.firstResponder is NSTextView { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !flags.isEmpty { return event } // только без модификаторов

            var handled = true
            var toast: String? = nil
            switch event.keyCode {
            case 49: // Space
                toast = "⏯ Пауза"
                NotificationCenter.default.post(name: .playerTogglePlay, object: nil)
            case 46: // M
                toast = "🔇 Мьют"
                NotificationCenter.default.post(name: .playerToggleMute, object: nil)
            case 3: // F
                toast = "⛶ Фуллскрин"
                NotificationCenter.default.post(name: .playerFullscreen, object: nil)
            case 124: // →
                toast = "→ +10с"
                NotificationCenter.default.post(name: .playerSeek, object: 10)
            case 123: // ←
                toast = "← -10с"
                NotificationCenter.default.post(name: .playerSeek, object: -10)
            case 45: // N
                toast = "След. серия"
                NotificationCenter.default.post(name: .playerNextEpisode, object: nil)
            case 11: // B
                toast = "Пред. серия"
                NotificationCenter.default.post(name: .playerPrevEpisode, object: nil)
            case 1: // S
                toast = "Пропуск опенинга +85с"
                NotificationCenter.default.post(name: .playerSeek, object: 85)
            default: handled = false
            }
            if let t = toast {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .playerHotkeyToast, object: t)
                }
            }
            return handled ? nil : event
        }
    }
}

// MARK: - Notifications для WebView
extension Notification.Name {
    static let playerTogglePlay = Notification.Name("playerTogglePlay")
    static let playerToggleMute = Notification.Name("playerToggleMute")
    static let playerFullscreen = Notification.Name("playerFullscreen")
    static let playerSeek = Notification.Name("playerSeek")
    static let playerVolumeChanged = Notification.Name("playerVolumeChanged")
    static let playerNextEpisode = Notification.Name("playerNextEpisode")
    static let playerPrevEpisode = Notification.Name("playerPrevEpisode")
    static let playerHotkeyToast = Notification.Name("playerHotkeyToast")
}

// MARK: - WebView с инъекциями как в AniDesk
struct WebView: NSViewRepresentable {
    let url: URL
    let quality: Int = 0
    let speed: Double = 1.0
    let volume: Double = 0.5
    let aspectRatio: String = "16-9"
    let upscaleEnabled: Bool = false
    let upscaleMode: Int = 15

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        // User-Agent как в AniDesk main.js UserAgent
        // WKWebView customUserAgent (macOS 11+)
        // Отложим установку до создания webview

        // Добавим скрипт для сообщений и Anime4K
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "anilanglia")
        // Инжектим Anime4K-заглушку заранее
        userContent.addUserScript(WKUserScript(source: anime4kPreloadJS(mode: upscaleMode), injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.userContentController = userContent

        let webview = WKWebView(frame: .zero, configuration: config)
        webview.allowsBackForwardNavigationGestures = false
        webview.customUserAgent = PlayerSettings.anixartUserAgent
        webview.navigationDelegate = context.coordinator
        // Подписка на нотификации плеера
        context.coordinator.webView = webview
        context.coordinator.installObservers()
        return webview
    }

    func updateNSView(_ webview: WKWebView, context: Context) {
        // Перезагрузка только при смене URL
        if webview.url != url {
            var req = URLRequest(url: url)
            // Referer как в AniDesk webRequest.onBeforeSendHeaders
            let host = url.host ?? ""
            if host.contains("sibnet.ru") {
                req.setValue(url.absoluteString, forHTTPHeaderField: "Referer")
            } else if host.contains("kodik") {
                req.setValue("https://anixart.tv", forHTTPHeaderField: "Referer")
            }
            req.setValue(PlayerSettings.anixartUserAgent, forHTTPHeaderField: "User-Agent")
            webview.load(req)
        } else {
            // Живое обновление без перезагрузки
            applySettings(to: webview)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        weak var webView: WKWebView?
        var observers: [Any] = []

        init(_ parent: WebView) { self.parent = parent }

        func installObservers() {
            observers = [
                NotificationCenter.default.addObserver(forName: .playerTogglePlay, object: nil, queue: .main) { _ in self.js("document.querySelectorAll('video').forEach(v=>v.paused?v.play():v.pause())") },
                NotificationCenter.default.addObserver(forName: .playerToggleMute, object: nil, queue: .main) { _ in self.js("document.querySelectorAll('video').forEach(v=>v.muted=!v.muted)") },
                NotificationCenter.default.addObserver(forName: .playerFullscreen, object: nil, queue: .main) { _ in self.js("let v=document.querySelector('video'); if(v){ if(document.fullscreenElement) document.exitFullscreen(); else (v.requestFullscreen?v.requestFullscreen():v.webkitEnterFullscreen&&v.webkitEnterFullscreen()) } else { document.documentElement.requestFullscreen&&document.documentElement.requestFullscreen()}") },
                NotificationCenter.default.addObserver(forName: .playerSeek, object: nil, queue: .main) { n in if let d=n.object as? Int { self.js("document.querySelectorAll('video').forEach(v=>v.currentTime=Math.max(0, v.currentTime+\(d)))") } },
                NotificationCenter.default.addObserver(forName: .playerVolumeChanged, object: nil, queue: .main) { n in if let v=n.object as? Double { self.js("document.querySelectorAll('video').forEach(v=>v.volume=\(v))") } }
            ]
        }
        deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

        func js(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        // После загрузки применяем настройки
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            apply()
        }
        func apply() {
            guard let wv = webView else { return }
            let p = parent
            // Скорость, громкость, соотношение
            var js = """
            (()=> {
              let vids = document.querySelectorAll('video');
              vids.forEach(v=>{ v.playbackRate=\(p.speed); v.volume=\(p.volume); v.setAttribute('playsinline',''); v.autoplay=\(PlayerSettings.shared.autoplayEpisode ? "true":"false"); });
            """
            // Соотношение
            switch p.aspectRatio {
            case "4-3": js += "document.querySelectorAll('video').forEach(v=>v.style.objectFit='contain', v.style.aspectRatio='4/3');"
            case "fit": js += "document.querySelectorAll('video').forEach(v=>v.style.objectFit='contain', v.style.aspectRatio='auto');"
            default: js += "document.querySelectorAll('video').forEach(v=>v.style.objectFit='contain', v.style.aspectRatio='16/9');"
            }
            // Выбор качества — пробуем найти селектор качества Kodik/Sibnet
            if p.quality != 0 {
                js += "try{ let q='\(p.quality)'; document.querySelectorAll('video source').forEach(s=>{ if(s.src.includes(q)) s.parentElement.src=s.src; }); }catch(e){}"
            }
            // Anime4K
            if p.upscaleEnabled {
                js += anime4kApplyJS(mode: p.upscaleMode)
            } else {
                js += "document.querySelectorAll('video').forEach(v=>v.style.filter='');"
            }
            js += "})();"
            wv.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
    }

    // MARK: - Helpers
    private func applySettings(to webview: WKWebView) {
        // Тригерим apply через координатор
        if let coord = webview.navigationDelegate as? Coordinator {
            coord.parent = self
            coord.apply()
        } else {
            let js = """
            document.querySelectorAll('video').forEach(v=>{ v.playbackRate=\(speed); v.volume=\(volume); });
            """
            webview.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func anime4kPreloadJS(mode: Int) -> String {
        // Предзагрузка: проверяем WebGPU, иначе готовим CSS fallback
        return """
        window.__anianglia_upscaleMode = \(mode);
        console.log('[AniAnglia] Anime4K preload mode', window.__anianglia_upscaleMode);
        """
    }
    private static func anime4kApplyJS(mode: Int) -> String {
        return """
        (()=> {
          let vids=document.querySelectorAll('video');
          if(!vids.length) return;
          let hasGPU = !!navigator.gpu;
          if(!hasGPU){
            vids.forEach(v=>v.style.filter='contrast(1.08) saturate(1.12) brightness(1.02)');
            console.log('[AniAnglia] Anime4K fallback CSS (WebGPU недоступен)');
            return;
          }
          if(!window.anime4k){
            let s=document.createElement('script');
            s.src='https://cdn.jsdelivr.net/npm/anime4k-webgpu@1.0.0/dist/anime4k.js';
            s.onload=()=>{ try{ window.anime4k.apply(vids, {mode: \(mode)}); console.log('[AniAnglia] Anime4K applied mode \(mode)'); }catch(e){ console.log(e); vids.forEach(v=>v.style.filter='contrast(1.08) saturate(1.12)'); } };
            s.onerror=()=>{ vids.forEach(v=>v.style.filter='contrast(1.08) saturate(1.12)'); };
            document.head.appendChild(s);
          } else {
            try{ window.anime4k.apply(vids, {mode: \(mode)}); }catch(e){ vids.forEach(v=>v.style.filter='contrast(1.08) saturate(1.12)'); }
          }
        })();
        """
    }
    private func anime4kApplyJS(mode: Int) -> String { Self.anime4kApplyJS(mode: mode) }
}

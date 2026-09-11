import Foundation
import SwiftUI

// MARK: - Адаптация AniDesk utils.ts под macOS (Swift)

// Совместимо с AniDesk playerDefaultSettings / playingDefaultSettings / upscaleDefaultSettings
final class PlayerSettings: ObservableObject {
    static let shared = PlayerSettings()

    // MARK: - Воспроизведение (playingDefaultSettings)
    @AppStorage("player_defaultQuality") var defaultQuality: Int = 1080 // 360/480/720/1080
    @AppStorage("player_defaultSource") var defaultSourceRaw: String = "auto" // auto, kodik, libria, sibnet
    @AppStorage("player_disableHistory") var disableHistory: Bool = false
    @AppStorage("player_autoplayEpisode") var autoplayEpisode: Bool = true

    // MARK: - Интерфейс плеера (playerDefaultSettings)
    @AppStorage("player_defaultAspectRatio") var defaultAspectRatio: String = "16-9" // 16-9, 4-3, fit
    @AppStorage("player_defaultVolume") var defaultVolume: Double = 0.5 // 0..1 (AniDesk 50 -> 0.5)
    @AppStorage("player_saveUserVolume") var saveUserVolumeEnabled: Bool = false
    @AppStorage("player_lastVolume") var lastVolume: Double = 0.5
    @AppStorage("player_opacityInterface") var opacityInterface: Double = 0.5
    @AppStorage("player_speed") var playbackSpeed: Double = 1.0

    // MARK: - Апскейл Anime4K (upscaleDefaultSettings)
    @AppStorage("upscale_enabled") var upscaleEnabled: Bool = false
    @AppStorage("upscale_mode") var upscaleMode: Int = 15 // 15 = ModeB [Preset] — как в AniDesk по умолчанию

    // MARK: - Hotkeys (как в AniDesk)
    // Оставили имена из AniDesk для совместимости, но на macOS маппим на NSEvent
    var hotkeys: [String: [String]] {
        [
            "hotkeyPlayPause": ["Space"],
            "hotkeyNextEpisode": ["KeyN"],
            "hotkeyPrevEpisode": ["KeyB"],
            "hotkeySkipOpening": ["KeyS"],
            "hotkeyForward": ["ArrowRight"],
            "hotkeyBackward": ["ArrowLeft"],
            "hotkeyMute": ["KeyM"],
            "hotkeyFullscreen": ["KeyF"]
        ]
    }

    var effectiveVolume: Double {
        saveUserVolumeEnabled ? lastVolume : defaultVolume
    }

    func saveVolume(_ v: Double) {
        let clamped = min(max(v, 0), 1)
        if saveUserVolumeEnabled { lastVolume = clamped }
    }
}

// MARK: - Значения как в AniDesk utils.ts
extension PlayerSettings {
    static let qualityValues: [(label: String, value: Int)] = [
        ("1080p", 1080), ("720p", 720), ("480p", 480), ("360p", 360)
    ]
    static let aspectRatioValues: [(label: String, value: String)] = [
        ("16:9", "16-9"), ("4:3", "4-3"), ("Fit", "fit")
    ]
    static let playerSpeedValues: [(label: String, value: Double)] = [
        ("0.5x", 0.5), ("1x", 1.0), ("1.5x", 1.5), ("2x", 2.0)
    ]
    static let sourceValues: [(label: String, value: String)] = [
        ("Авто", "auto"), ("Kodik", "kodik"), ("Libria", "libria"), ("Sibnet", "sibnet")
    ]
    // Режимы Anime4K из AniDesk utils.ts upscaleValues
    static let upscaleValues: [(label: String, value: Int, description: String)] = [
        ("ModeA [Preset]", 14, "Быстрый пресет с умеренным восстановлением."),
        ("ModeB [Preset]", 15, "Сбалансированный пресет с акцентом на детализацию."),
        ("ModeC [Preset]", 16, "Качественный пресет с более агрессивным улучшением."),
        ("ModeA+A [Preset]", 17, "Расширенный ModeA."),
        ("ModeB+B [Preset]", 18, "Улучшенный ModeB."),
        ("ModeC+A [Preset]", 19, "Комбинированный с высокой чёткостью."),
        ("DoG [Deblur]", 0, "Удаление размытия."),
        ("BilateralMean [Denoise]", 1, "Снижение шума."),
        ("CNNM [Restore]", 2, "Нейросетевое восстановление."),
        ("CNNSoftM [Restore]", 3, "Мягкое восстановление."),
        ("CNNx2M [Upscale]", 8, "Увеличение в 2 раза."),
        ("GANUUL [Restore]", 7, "GAN реконструкция."),
        ("GANx3L [Upscale]", 12, "Апскейл в 3 раза."),
        ("GANx4UUL [Upscale]", 13, "Апскейл в 4 раза.")
    ]

    static let anixartUserAgent = "AnixartApp/9.0 BETA 3-25021818 (Android 9; SDK 28; x86_64; ROG ASUS AI2201_B; ru)"
}

// MARK: - Sibnet парсер (как в AniDesk ipcMain handle sibnet:parse -> SibnetParser.getDirectLink)
// Упрощённый Swift-порт: вытаскивает прямую ссылку из страницы sibnet
enum SibnetParser {
    static func directLink(for pageURL: URL) async throws -> URL {
        var req = URLRequest(url: pageURL)
        req.setValue(PlayerSettings.anixartUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(pageURL.absoluteString, forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        // Ищем src вида "/v/p/...mp4" или "https://video.sibnet.ru/..."
        // Пример из anixartjs: парсит <source src="...">
        let patterns = [
            #"src\s*=\s*['\"]([^'\"]*sibnet[^'\"]*\.mp4[^'\"]*)['\"]"#,
            #"src\s*:\s*['\"]([^'\"]+\.mp4)['\"]"#,
            #"url\s*:\s*['\"]([^'\"]+\.mp4)['\"]"#,
            #"(https?://video\.sibnet\.ru[^\s'\"<>]+\.mp4[^\s'\"<>]*)"#,
            #"(/v/[^\s'\"<>]+\.mp4[^\s'\"<>]*)"#
        ]
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive),
               let m = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let r = Range(m.range(at: 1), in: html) {
                var found = String(html[r])
                if found.hasPrefix("/") { found = "https://video.sibnet.ru" + found }
                if let url = URL(string: found) { return url }
            }
        }
        // Fallback — возвращаем исходный URL, WKWebView сам обработает
        return pageURL
    }
}

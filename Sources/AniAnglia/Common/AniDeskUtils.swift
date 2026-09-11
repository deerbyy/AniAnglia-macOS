import Foundation

// MARK: - Порт AniDesk utils.ts под macOS (Swift)
// Совместимость с AniDesk: seasons, player значения, bookmarkSort etc.
// Используется в Home/Bookmarks/Settings и для отображения релизов.

enum AniDeskUtils {
    // MARK: - Сезоны
    static let seasons: [String?] = [nil, "Зима", "Весна", "Лето", "Осень"]

    // MARK: - Значения из utils.ts (для Picker'ов)
    static let bookmarkSortValues: [(label: String, value: Int)] = [
        ("По дате добавления: сначала новые", 1),
        ("По дате добавления: сначала старые", 2),
        ("По году выхода: сначала новые", 3),
        ("По году выхода: сначала старые", 4),
        ("По алфавиту: A → Z", 5),
        ("По алфавиту: Z → A", 6),
    ]
    static let collectionSortValues: [(label: String, value: Int)] = [
        ("В закладках", 0),
        ("Лидеры рейтинга", 1),
        ("Популярные за год", 2),
        ("Популярные за сезон", 3),
        ("Популярные за неделю", 4),
        ("Недавно добавленные", 5),
        ("Случайные", 6),
    ]
    static let endpointValues: [(label: String, value: String)] = [
        ("api-s.anixsekai.com", "api-s.anixsekai.com"),
        ("api.anixart.app", "api.anixart.app"),
        ("api.anixart.tv (Заблокирован в РФ)", "api.anixart.tv"),
    ]
    static let privacyOptions: [(label: String, value: Int)] = [
        ("Никто", 2), ("Только друзья", 1), ("Все пользователи", 0)
    ]

    // MARK: - Время
    static func getStringTime(minutes: Int) -> (days: Int, hours: Int, minutes: Int) {
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        return (days, hours, minutes)
    }
    static func getNumericWord(_ number: Int, words: [String]) -> String {
        let cases = [2, 0, 1, 1, 1, 2]
        let idx: Int
        if number % 100 > 4 && number % 100 < 20 {
            idx = 2
        } else {
            let n = number % 10
            idx = cases[n < 5 ? n : 5]
        }
        return words[idx]
    }
    static func returnFullStringTime(minutes: Int) -> String {
        let (days, hours, _) = getStringTime(minutes: minutes)
        let dayWord = getNumericWord(days, words: ["день", "дня", "дней"])
        if hours != 0 {
            let hourWord = getNumericWord(hours, words: ["час", "часа", "часов"])
            return "\(days) \(dayWord) \(hours) \(hourWord)"
        }
        return "\(days) \(dayWord)"
    }
    static func returnEpisodeString(released: Int?, total: Int?) -> String {
        let r = released, t = total
        if t == nil && r == nil { return "?" }
        if let t, let r, t == r { return "\(t)" }
        let rStr = r.map { "\($0)" } ?? "?"
        let tStr = t.map { "\($0)" } ?? "?"
        return "\(rStr) из \(tStr)"
    }
    static func getAgeRate(_ rate: Int) -> String {
        switch rate {
        case 2: return "6+"
        case 3: return "12+"
        case 4: return "16+"
        case 5: return "18+"
        default: return "0+"
        }
    }
    static func getShortDate(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let cal = Calendar.current
        let d = cal.component(.day, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%02d.%02d", d, m)
    }
    static func returnTimeString(timestamp: TimeInterval, showYear: Bool = false) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = showYear ? "d MMM yyyy 'в' HH:mm" : "d MMM 'в' HH:mm"
        return df.string(from: date)
    }
    static func returnFormatedTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append(String(format: "%02d", h)) }
        parts.append(String(format: "%02d", m))
        parts.append(String(format: "%02d", s))
        return parts.joined(separator: ":")
    }
    // Дополнительные хелперы
    static func seasonName(for month: Int) -> String {
        switch month {
        case 12, 1, 2: return seasons[1] ?? ""
        case 3...5: return seasons[2] ?? ""
        case 6...8: return seasons[3] ?? ""
        default: return seasons[4] ?? ""
        }
    }
}

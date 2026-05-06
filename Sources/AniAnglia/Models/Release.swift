import Foundation

struct Release: Codable, Identifiable, Hashable {
    let id: Int64
    let titleRu: String?
    let titleOriginal: String?
    let titleAlt: String?
    let year: String?
    let country: String?
    let studio: String?
    let director: String?
    let author: String?
    let description: String?
    let image: String?
    let status: NamedItem?
    let category: NamedItem?
    let genres: String?
    let episodesTotal: Int?
    let episodesReleased: Int?
    let grade: Double?
    let screenshotImageUrls: [String]?
    let isFavorite: Bool?
    let profileListStatus: Int?
    let voteCount: Int?
    let yourVote: Int?

    var displayTitle: String {
        titleRu ?? titleOriginal ?? titleAlt ?? "Без названия"
    }

    var posterURL: URL? {
        image.flatMap { URL(string: $0) }
    }

    var screenshots: [URL] {
        (screenshotImageUrls ?? []).compactMap { URL(string: $0) }
    }

    init(
        id: Int64,
        titleRu: String?,
        titleOriginal: String?,
        titleAlt: String?,
        year: String?,
        country: String?,
        studio: String?,
        director: String?,
        author: String?,
        description: String?,
        image: String?,
        status: NamedItem?,
        category: NamedItem?,
        genres: String?,
        episodesTotal: Int?,
        episodesReleased: Int?,
        grade: Double?,
        screenshotImageUrls: [String]?,
        isFavorite: Bool?,
        profileListStatus: Int?,
        voteCount: Int?,
        yourVote: Int?
    ) {
        self.id = id
        self.titleRu = titleRu
        self.titleOriginal = titleOriginal
        self.titleAlt = titleAlt
        self.year = year
        self.country = country
        self.studio = studio
        self.director = director
        self.author = author
        self.description = description
        self.image = image
        self.status = status
        self.category = category
        self.genres = genres
        self.episodesTotal = episodesTotal
        self.episodesReleased = episodesReleased
        self.grade = grade
        self.screenshotImageUrls = screenshotImageUrls
        self.isFavorite = isFavorite
        self.profileListStatus = profileListStatus
        self.voteCount = voteCount
        self.yourVote = yourVote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ReleaseCodingKey.self)
        id = c.decodeInt64("id") ?? 0
        titleRu = c.decodeString("title_ru") ?? c.decodeString("titleRu") ?? c.decodeString("title")
        titleOriginal = c.decodeString("title_original") ?? c.decodeString("titleOriginal")
        titleAlt = c.decodeString("title_alt") ?? c.decodeString("titleAlt")
        year = c.decodeString("year")
        country = c.decodeString("country")
        studio = c.decodeString("studio")
        director = c.decodeString("director")
        author = c.decodeString("author")
        description = c.decodeString("description")
        image = c.decodeString("image") ?? c.decodeString("image_url") ?? c.decodeString("imageUrl")
        status = c.decodeNamedItem("status")
        category = c.decodeNamedItem("category")
        genres = c.decodeString("genres")
        episodesTotal = c.decodeInt("episodes_total") ?? c.decodeInt("episodesTotal")
        episodesReleased = c.decodeInt("episodes_released") ?? c.decodeInt("episodesReleased")
        grade = c.decodeDouble("grade")
        screenshotImageUrls = c.decodeStringArray("screenshot_image_urls") ?? c.decodeStringArray("screenshotImageUrls")
        isFavorite = c.decodeBool("is_favorite") ?? c.decodeBool("isFavorite")
        profileListStatus = c.decodeInt("profile_list_status") ?? c.decodeInt("profileListStatus")
        voteCount = c.decodeInt("vote_count") ?? c.decodeInt("voteCount")
        yourVote = c.decodeInt("your_vote") ?? c.decodeInt("yourVote") ?? c.decodeInt("my_vote") ?? c.decodeInt("myVote")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ReleaseCodingKey.self)
        try c.encode(id, forKey: "id")
        try c.encodeIfPresent(titleRu, forKey: "title_ru")
        try c.encodeIfPresent(titleOriginal, forKey: "title_original")
        try c.encodeIfPresent(titleAlt, forKey: "title_alt")
        try c.encodeIfPresent(year, forKey: "year")
        try c.encodeIfPresent(country, forKey: "country")
        try c.encodeIfPresent(studio, forKey: "studio")
        try c.encodeIfPresent(director, forKey: "director")
        try c.encodeIfPresent(author, forKey: "author")
        try c.encodeIfPresent(description, forKey: "description")
        try c.encodeIfPresent(image, forKey: "image_url")
        try c.encodeIfPresent(status, forKey: "status")
        try c.encodeIfPresent(category, forKey: "category")
        try c.encodeIfPresent(genres, forKey: "genres")
        try c.encodeIfPresent(episodesTotal, forKey: "episodes_total")
        try c.encodeIfPresent(episodesReleased, forKey: "episodes_released")
        try c.encodeIfPresent(grade, forKey: "grade")
        try c.encodeIfPresent(screenshotImageUrls, forKey: "screenshot_image_urls")
        try c.encodeIfPresent(isFavorite, forKey: "is_favorite")
        try c.encodeIfPresent(profileListStatus, forKey: "profile_list_status")
        try c.encodeIfPresent(voteCount, forKey: "vote_count")
        try c.encodeIfPresent(yourVote, forKey: "your_vote")
    }

    func withProfileListStatus(_ status: Int?) -> Release {
        Release(
            id: id,
            titleRu: titleRu,
            titleOriginal: titleOriginal,
            titleAlt: titleAlt,
            year: year,
            country: country,
            studio: studio,
            director: director,
            author: author,
            description: description,
            image: image,
            status: self.status,
            category: category,
            genres: genres,
            episodesTotal: episodesTotal,
            episodesReleased: episodesReleased,
            grade: grade,
            screenshotImageUrls: screenshotImageUrls,
            isFavorite: isFavorite,
            profileListStatus: status,
            voteCount: voteCount,
            yourVote: yourVote
        )
    }

    func withFavorite(_ favorite: Bool?) -> Release {
        Release(
            id: id,
            titleRu: titleRu,
            titleOriginal: titleOriginal,
            titleAlt: titleAlt,
            year: year,
            country: country,
            studio: studio,
            director: director,
            author: author,
            description: description,
            image: image,
            status: status,
            category: category,
            genres: genres,
            episodesTotal: episodesTotal,
            episodesReleased: episodesReleased,
            grade: grade,
            screenshotImageUrls: screenshotImageUrls,
            isFavorite: favorite,
            profileListStatus: profileListStatus,
            voteCount: voteCount,
            yourVote: yourVote
        )
    }
}

enum BookmarkCategory: Int, CaseIterable, Identifiable, Hashable {
    case watching = 1
    case planned = 2
    case watched = 3
    case onHold = 4
    case dropped = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .planned: return "В планах"
        case .watching: return "Смотрю"
        case .watched: return "Просмотрено"
        case .onHold: return "Отложено"
        case .dropped: return "Брошено"
        }
    }

    static let displayOrder: [BookmarkCategory] = [.watching, .planned, .watched, .onHold, .dropped]
}

enum AccountLibrarySection: Hashable, Identifiable {
    case favorites
    case favoriteCollections
    case list(BookmarkCategory)

    var id: String {
        switch self {
        case .favorites: return "favorites"
        case .favoriteCollections: return "favorite-collections"
        case .list(let category): return "list-\(category.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .favorites: return "Избранное"
        case .favoriteCollections: return "Коллекции"
        case .list(let category): return category.title
        }
    }

    static let displayOrder: [AccountLibrarySection] = [.favorites, .favoriteCollections] + BookmarkCategory.displayOrder.map(AccountLibrarySection.list)
}

struct NamedItem: Codable, Hashable {
    let id: Int?
    let name: String?

    init(id: Int?, name: String?) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: ReleaseCodingKey.self) {
            id = container.decodeInt("id")
            name = container.decodeString("name") ?? id.map(String.init)
            return
        }
        let single = try decoder.singleValueContainer()
        if let intValue = try? single.decode(Int.self) {
            id = intValue
            name = String(intValue)
        } else if let stringValue = try? single.decode(String.self) {
            id = Int(stringValue)
            name = stringValue
        } else {
            id = nil
            name = nil
        }
    }
}

struct ReleasesResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let releases: [Release]
    let content: [Release]
    let totalCount: Int?
    let totalPageCount: Int?
    let currentPage: Int?

    /// Catalog/filter responses use `content`, search uses `releases`.
    var items: [Release] { releases.isEmpty ? content : releases }

    enum CodingKeys: String, CodingKey {
        case code, message, releases, content, totalCount, totalPageCount, currentPage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.releases = (try? c.decode([Release].self, forKey: .releases)) ?? []
        self.content = (try? c.decode([Release].self, forKey: .content)) ?? []
        self.totalCount = try? c.decode(Int.self, forKey: .totalCount)
        self.totalPageCount = try? c.decode(Int.self, forKey: .totalPageCount)
        self.currentPage = try? c.decode(Int.self, forKey: .currentPage)
    }
}

struct ReleaseCodingKey: CodingKey, ExpressibleByStringLiteral {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init(stringLiteral value: String) {
        self.init(value)
    }
}

extension KeyedEncodingContainer where Key == ReleaseCodingKey {
    mutating func encode<T: Encodable>(_ value: T, forKey key: String) throws {
        try encode(value, forKey: ReleaseCodingKey(key))
    }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: String) throws {
        try encodeIfPresent(value, forKey: ReleaseCodingKey(key))
    }
}

extension KeyedDecodingContainer where Key == ReleaseCodingKey {
    func decodeString(_ key: String) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: ReleaseCodingKey(key)), !value.isEmpty {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: ReleaseCodingKey(key)) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: ReleaseCodingKey(key)) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: ReleaseCodingKey(key)) {
            return String(value)
        }
        return nil
    }

    func decodeInt(_ key: String) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: ReleaseCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: ReleaseCodingKey(key)) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: ReleaseCodingKey(key)) {
            return Int(value)
        }
        return nil
    }

    func decodeInt64(_ key: String) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: ReleaseCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: ReleaseCodingKey(key)) {
            return Int64(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: ReleaseCodingKey(key)) {
            return Int64(value)
        }
        return nil
    }

    func decodeDouble(_ key: String) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: ReleaseCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: ReleaseCodingKey(key)) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: ReleaseCodingKey(key)) {
            return Double(value.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    func decodeBool(_ key: String) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: ReleaseCodingKey(key)) {
            return value
        }
        if let value = decodeInt(key) {
            return value != 0
        }
        if let value = decodeString(key)?.lowercased() {
            return ["true", "yes", "1"].contains(value)
        }
        return nil
    }

    func decodeStringArray(_ key: String) -> [String]? {
        if let value = try? decodeIfPresent([String].self, forKey: ReleaseCodingKey(key)) {
            return value
        }
        if let value = decodeString(key), !value.isEmpty {
            return [value]
        }
        return nil
    }

    func decodeNamedItem(_ key: String) -> NamedItem? {
        if let value = try? decodeIfPresent(NamedItem.self, forKey: ReleaseCodingKey(key)) {
            return value
        }
        if let id = decodeInt(key) {
            return NamedItem(id: id, name: String(id))
        }
        if let name = decodeString(key) {
            return NamedItem(id: Int(name), name: name)
        }
        return nil
    }
}

struct ReleaseResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let release: Release?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.release = try? c.decode(Release.self, forKey: .release)
    }

    enum CodingKeys: String, CodingKey { case code, message, release }
}

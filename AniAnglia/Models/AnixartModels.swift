import Foundation

struct NamedID: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

typealias Genre = NamedID

struct AuthSession: Codable, Equatable {
    let token: String
    let profileId: Int
    let profile: Profile?
}

struct SearchFilters: Equatable {
    var genreId: Int?
    var year: Int?
    var type: Int?

    static let empty = SearchFilters()
}

struct PagedReleases: Decodable, Equatable {
    let releases: [ReleaseSummary]
    let totalCount: Int
    let totalPageCount: Int

    init(releases: [ReleaseSummary], totalCount: Int, totalPageCount: Int) {
        self.releases = releases
        self.totalCount = totalCount
        self.totalPageCount = totalPageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        releases = try container.decodeIfPresent([ReleaseSummary].self, forKey: .releases) ?? []
        totalCount = container.decodeFlexibleIntIfPresent(forKey: .totalCount) ?? releases.count
        totalPageCount = container.decodeFlexibleIntIfPresent(forKey: .totalPageCount) ?? 1
    }

    enum CodingKeys: String, CodingKey {
        case releases
        case totalCount = "total_count"
        case totalPageCount = "total_page_count"
    }
}

struct ReleaseSummary: Decodable, Identifiable, Equatable {
    let id: Int
    let titleRu: String?
    let titleOriginal: String?
    let year: Int?
    let genres: [String]
    let image: String?
    let status: String?
    let episodesTotal: Int?
    let episodesReleased: Int?
    let grade: Double?
    let favoriteCategory: FavoriteCategory?
    let watchStatus: WatchListStatus?

    var displayTitle: String {
        titleRu.nonEmpty ?? titleOriginal.nonEmpty ?? "Релиз #\(id)"
    }

    var subtitle: String {
        [year.map(String.init), status.nonEmpty].compactMap { $0 }.joined(separator: " - ")
    }

    init(
        id: Int,
        titleRu: String?,
        titleOriginal: String?,
        year: Int?,
        genres: [String],
        image: String?,
        status: String?,
        episodesTotal: Int?,
        episodesReleased: Int?,
        grade: Double?,
        favoriteCategory: FavoriteCategory?,
        watchStatus: WatchListStatus?
    ) {
        self.id = id
        self.titleRu = titleRu
        self.titleOriginal = titleOriginal
        self.year = year
        self.genres = genres
        self.image = image
        self.status = status
        self.episodesTotal = episodesTotal
        self.episodesReleased = episodesReleased
        self.grade = grade
        self.favoriteCategory = favoriteCategory
        self.watchStatus = watchStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleIntIfPresent(forKey: .id) ?? 0
        titleRu = container.decodeFlexibleStringIfPresent(forKey: .titleRu)
            ?? container.decodeFlexibleStringIfPresent(forKey: .title)
        titleOriginal = container.decodeFlexibleStringIfPresent(forKey: .titleOriginal)
            ?? container.decodeFlexibleStringIfPresent(forKey: .titleEn)
        year = container.decodeFlexibleIntIfPresent(forKey: .year)
        genres = container.decodeStringListIfPresent(forKey: .genres)
        image = container.decodeFlexibleStringIfPresent(forKey: .image)
        status = container.decodeFlexibleStringIfPresent(forKey: .status)
        episodesTotal = container.decodeFlexibleIntIfPresent(forKey: .episodesTotal)
        episodesReleased = container.decodeFlexibleIntIfPresent(forKey: .episodesReleased)
        grade = container.decodeFlexibleDoubleIfPresent(forKey: .grade)
        favoriteCategory = container.decodeEnumIfPresent(FavoriteCategory.self, forKey: .favoriteCategory)
        watchStatus = container.decodeEnumIfPresent(WatchListStatus.self, forKey: .watchStatus)
            ?? container.decodeEnumIfPresent(WatchListStatus.self, forKey: .profileListStatus)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleRu = "title_ru"
        case titleEn = "title_en"
        case titleOriginal = "title_original"
        case year
        case genres
        case image
        case status
        case episodesTotal = "episodes_total"
        case episodesReleased = "episodes_released"
        case grade
        case favoriteCategory = "favorite_category"
        case watchStatus = "watch_status"
        case profileListStatus = "profile_list_status"
    }
}

struct ReleaseDetail: Decodable, Identifiable, Equatable {
    let summary: ReleaseSummary
    let country: String?
    let studio: String?
    let director: String?
    let description: String?
    let screenshotImageUrls: [String]
    let videoBanners: [ReleaseVideoBanner]

    var id: Int { summary.id }
    var displayTitle: String { summary.displayTitle }

    init(summary: ReleaseSummary, country: String?, studio: String?, director: String?, description: String?, screenshotImageUrls: [String], videoBanners: [ReleaseVideoBanner]) {
        self.summary = summary
        self.country = country
        self.studio = studio
        self.director = director
        self.description = description
        self.screenshotImageUrls = screenshotImageUrls
        self.videoBanners = videoBanners
    }

    init(from decoder: Decoder) throws {
        summary = try ReleaseSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        country = container.decodeFlexibleStringIfPresent(forKey: .country)
        studio = container.decodeFlexibleStringIfPresent(forKey: .studio)
        director = container.decodeFlexibleStringIfPresent(forKey: .director)
        description = container.decodeFlexibleStringIfPresent(forKey: .description)
        screenshotImageUrls = container.decodeStringListIfPresent(forKey: .screenshotImageUrls)
        videoBanners = try container.decodeIfPresent([ReleaseVideoBanner].self, forKey: .videoBanners) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case country
        case studio
        case director
        case description
        case screenshotImageUrls = "screenshot_image_urls"
        case videoBanners = "video_banners"
    }
}

struct ReleaseVideoBanner: Codable, Identifiable, Equatable {
    var id: String { image ?? url ?? UUID().uuidString }
    let image: String?
    let url: String?
    let playerUrl: String?

    enum CodingKeys: String, CodingKey {
        case image
        case url
        case playerUrl = "player_url"
    }
}

struct EpisodeList: Decodable, Equatable {
    let episodes: [Episode]
    let types: [NamedID]
}

struct Episode: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let position: Int?
    let sources: [EpisodeSource]

    init(id: Int, name: String, position: Int?, sources: [EpisodeSource]) {
        self.id = id
        self.name = name
        self.position = position
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleIntIfPresent(forKey: .id) ?? 0
        name = container.decodeFlexibleStringIfPresent(forKey: .name) ?? "Эпизод \(id)"
        position = container.decodeFlexibleIntIfPresent(forKey: .position)
        sources = try container.decodeIfPresent([EpisodeSource].self, forKey: .sources) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case position
        case sources
    }
}

struct EpisodeSource: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let episodesCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case episodesCount = "episodes_count"
    }
}

struct EpisodePlayer: Decodable, Equatable {
    let url: String?
    let sources: [EpisodeSource]
}

struct VideoBlock: Decodable, Identifiable, Equatable {
    var id: Int { category.id }
    let category: NamedID
    let videos: [ReleaseVideo]
}

struct ReleaseVideo: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let image: String?
    let url: String?
    let playerUrl: String?
    let hosting: NamedID?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case image
        case url
        case playerUrl = "player_url"
        case hosting
    }
}

struct PagedComments: Decodable, Equatable {
    let comments: [Comment]
    let totalCount: Int
    let totalPageCount: Int

    init(comments: [Comment], totalCount: Int, totalPageCount: Int) {
        self.comments = comments
        self.totalCount = totalCount
        self.totalPageCount = totalPageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
        totalCount = container.decodeFlexibleIntIfPresent(forKey: .totalCount) ?? comments.count
        totalPageCount = container.decodeFlexibleIntIfPresent(forKey: .totalPageCount) ?? 1
    }

    enum CodingKeys: String, CodingKey {
        case comments
        case totalCount = "total_count"
        case totalPageCount = "total_page_count"
    }
}

struct Comment: Decodable, Identifiable, Equatable {
    let id: Int
    let message: String
    let profile: Profile?
    let votesCount: Int

    init(id: Int, message: String, profile: Profile?, votesCount: Int) {
        self.id = id
        self.message = message
        self.profile = profile
        self.votesCount = votesCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleIntIfPresent(forKey: .id) ?? 0
        message = container.decodeFlexibleStringIfPresent(forKey: .message) ?? ""
        profile = try container.decodeIfPresent(Profile.self, forKey: .profile)
        votesCount = container.decodeFlexibleIntIfPresent(forKey: .votesCount) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case profile
        case votesCount = "votes_count"
    }
}

struct Profile: Codable, Identifiable, Equatable {
    let id: Int
    let login: String?
    let nickname: String?
    let avatar: String?
    let status: String?
    let favoritesCount: Int?
    let watchedCount: Int?

    var displayName: String {
        nickname.nonEmpty ?? login.nonEmpty ?? "Профиль #\(id)"
    }

    init(id: Int, login: String?, nickname: String?, avatar: String?, status: String?, favoritesCount: Int?, watchedCount: Int?) {
        self.id = id
        self.login = login
        self.nickname = nickname
        self.avatar = avatar
        self.status = status
        self.favoritesCount = favoritesCount
        self.watchedCount = watchedCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodeKeys.self)
        id = container.decodeFlexibleIntIfPresent(forKey: .id) ?? 0
        login = container.decodeFlexibleStringIfPresent(forKey: .login)
        nickname = container.decodeFlexibleStringIfPresent(forKey: .nickname)
            ?? container.decodeFlexibleStringIfPresent(forKey: .name)
        avatar = container.decodeFlexibleStringIfPresent(forKey: .avatar)
            ?? container.decodeFlexibleStringIfPresent(forKey: .image)
        status = container.decodeFlexibleStringIfPresent(forKey: .status)
        favoritesCount = container.decodeFlexibleIntIfPresent(forKey: .favoritesCount)
        watchedCount = container.decodeFlexibleIntIfPresent(forKey: .watchedCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(login, forKey: .login)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(favoritesCount, forKey: .favoritesCount)
        try container.encodeIfPresent(watchedCount, forKey: .watchedCount)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case nickname
        case avatar
        case status
        case favoritesCount = "favorites_count"
        case watchedCount = "watched_count"
    }

    enum DecodeKeys: String, CodingKey {
        case id
        case login
        case nickname
        case name
        case avatar
        case image
        case status
        case favoritesCount = "favorites_count"
        case watchedCount = "watched_count"
    }
}

enum FavoriteCategory: Int, Codable, CaseIterable, Identifiable {
    case planned = 1
    case watching = 2
    case watched = 3
    case onHold = 4
    case dropped = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .watching: "Смотрю"
        case .planned: "В планах"
        case .watched: "Просмотрено"
        case .onHold: "Отложено"
        case .dropped: "Брошено"
        }
    }
}

enum WatchListStatus: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case planned = 1
    case watching = 2
    case watched = 3
    case onHold = 4
    case dropped = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "Удалить"
        case .planned: "В планах"
        case .watching: "Смотрю"
        case .watched: "Просмотрено"
        case .onHold: "Отложено"
        case .dropped: "Брошено"
        }
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return String(double)
        }
        if let named = try? decodeIfPresent(NamedID.self, forKey: key) {
            return named.name
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return int
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return double
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(int)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Double(string.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    func decodeStringListIfPresent(forKey key: Key) -> [String] {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values
        }
        if let values = try? decodeIfPresent([NamedID].self, forKey: key) {
            return values.map(\.name)
        }
        if let value = decodeFlexibleStringIfPresent(forKey: key), !value.isEmpty {
            return [value]
        }
        return []
    }

    func decodeEnumIfPresent<T: RawRepresentable>(_ type: T.Type, forKey key: Key) -> T? where T.RawValue == Int {
        guard let raw = decodeFlexibleIntIfPresent(forKey: key) else {
            return nil
        }
        return T(rawValue: raw)
    }
}

extension ReleaseSummary {
    static let preview = ReleaseSummary(
        id: 2,
        titleRu: "Стальной алхимик: Братство",
        titleOriginal: "Fullmetal Alchemist: Brotherhood",
        year: 2009,
        genres: ["экшен", "приключения", "драма"],
        image: nil,
        status: "завершен",
        episodesTotal: 64,
        episodesReleased: 64,
        grade: 8.9,
        favoriteCategory: .watched,
        watchStatus: .watched
    )

    static let previewList = [
        preview,
        ReleaseSummary(id: 3, titleRu: "Врата Штейна", titleOriginal: "Steins;Gate", year: 2011, genres: ["триллер", "фантастика"], image: nil, status: "завершен", episodesTotal: 24, episodesReleased: 24, grade: 8.8, favoriteCategory: .planned, watchStatus: .planned),
        ReleaseSummary(id: 4, titleRu: "Фрирен, провожающая в последний путь", titleOriginal: "Sousou no Frieren", year: 2023, genres: ["фэнтези", "драма"], image: nil, status: "завершен", episodesTotal: 28, episodesReleased: 28, grade: 8.7, favoriteCategory: .watching, watchStatus: .watching)
    ]
}

extension ReleaseDetail {
    static func preview(id: Int = 2) -> ReleaseDetail {
        ReleaseDetail(
            summary: ReleaseSummary.preview,
            country: "Япония",
            studio: "Bones",
            director: "Ясухиро Ириэ",
            description: "Два брата-алхимика ищут философский камень после трагического эксперимента.",
            screenshotImageUrls: [],
            videoBanners: []
        )
    }
}

extension EpisodeSource {
    static let previewList = [
        EpisodeSource(id: 1, name: "Kodik", episodesCount: 64),
        EpisodeSource(id: 2, name: "Sibnet", episodesCount: 64)
    ]
}

extension Episode {
    static let previewList = [
        Episode(id: 1, name: "Начало пути", position: 1, sources: EpisodeSource.previewList),
        Episode(id: 2, name: "Цена обмена", position: 2, sources: EpisodeSource.previewList)
    ]
}

extension VideoBlock {
    static let previewList = [
        VideoBlock(category: NamedID(id: 1, name: "Трейлеры"), videos: [
            ReleaseVideo(id: 1, title: "PV1", image: nil, url: "https://youtu.be/JBZpDN0A82M", playerUrl: "https://youtube.com/embed/JBZpDN0A82M", hosting: NamedID(id: 2, name: "YouTube"))
        ])
    ]
}

extension Comment {
    static let previewList = [
        Comment(id: 1, message: "Отличный релиз.", profile: .preview, votesCount: 12),
        Comment(id: 2, message: "Нужен пересмотр.", profile: .preview, votesCount: 3)
    ]
}

extension Profile {
    static let preview = Profile(id: 1, login: "preview", nickname: "AniAnglia User", avatar: nil, status: "online", favoritesCount: 12, watchedCount: 24)
}

extension Genre {
    static let previewList = [
        Genre(id: 1, name: "экшен"),
        Genre(id: 2, name: "драма"),
        Genre(id: 3, name: "фэнтези")
    ]
}

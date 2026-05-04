import Foundation

extension AnixartAPI {
    // MARK: - Discover (Home feed)

    /// "Сейчас смотрят" — popular releases, paginated, returns `content`.
    func discoverWatching(page: Int = 0) async throws -> ReleasesResponse {
        try await get("discover/watching/\(page)")
    }

    /// Personal recommendations (auth required).
    func discoverRecommendations(page: Int = 0) async throws -> ReleasesResponse {
        try await get("discover/recommendations/\(page)")
    }

    // MARK: - Release

    func release(id: Int64) async throws -> Release {
        let resp: ReleaseResponse = try await get("release/\(id)")
        guard let release = resp.release else { throw APIError.server(code: resp.code, message: "Релиз не найден") }
        return release
    }

    func randomRelease() async throws -> Release {
        let resp: ReleaseResponse = try await get("release/random")
        guard let release = resp.release else { throw APIError.empty }
        return release
    }

    // MARK: - Search

    func searchReleases(query: String, page: Int = 0, searchBy: Int = 0) async throws -> ReleasesResponse {
        try await post("search/releases/\(page)", form: [
            "query": query,
            "searchBy": String(searchBy)
        ])
    }

    // MARK: - Catalog / Filter

    /// Sort: 0=DateUpdate, 1=Grade, 2=Year, 3=Popular
    func filter(
        page: Int = 0,
        sort: Int = 3,
        category: Int? = nil,
        status: Int? = nil,
        country: String? = nil,
        startYear: Int? = nil,
        endYear: Int? = nil,
        genres: [String] = [],
        excludeGenres: Bool = false
    ) async throws -> ReleasesResponse {
        var body: [String: Any] = [
            "sort": sort,
            "is_genres_exclude_mode": excludeGenres
        ]
        if let category { body["category"] = category }
        if let status { body["status"] = status }
        if let country { body["country"] = country }
        if let startYear { body["start_year"] = startYear }
        if let endYear { body["end_year"] = endYear }
        if !genres.isEmpty { body["genres"] = genres }
        return try await postJSON("filter/\(page)", body: body)
    }

    // MARK: - Episodes

    /// Список озвучек/типов эпизодов для релиза.
    func episodeTypes(releaseId: Int64) async throws -> [EpisodeType] {
        let resp: EpisodeTypesResponse = try await get("episode/\(releaseId)")
        return resp.types
    }

    /// Источники (плееры) для конкретной озвучки.
    func episodeSources(releaseId: Int64, typeId: Int) async throws -> [EpisodeSource] {
        let resp: EpisodeSourcesResponse = try await get("episode/\(releaseId)/\(typeId)")
        return resp.sources
    }

    /// Серии для конкретной озвучки + плеера.
    func episodes(releaseId: Int64, typeId: Int, sourceId: Int) async throws -> [Episode] {
        let resp: EpisodesResponse = try await get("episode/\(releaseId)/\(typeId)/\(sourceId)")
        return resp.episodes
    }

    // MARK: - Videos (release main blocks)

    func videoBlocks(releaseId: Int64) async throws -> VideoBlocksResponse {
        try await get("video/release/\(releaseId)")
    }

    // MARK: - Bookmarks / Profile lists

    /// Список релизов в категории закладок (для текущего пользователя).
    /// Категория: 1=Запланировано, 2=Смотрю, 3=Просмотрено, 4=Отложено, 5=Брошено
    func bookmarks(category: Int, page: Int = 0) async throws -> ReleasesResponse {
        guard let pid = auth.profileId else { throw APIError.server(code: 401, message: "Не авторизован") }
        return try await get("profile/list/all/\(pid)/\(category)/\(page)")
    }

    /// Добавить релиз в категорию (или переместить, если уже в другой).
    @discardableResult
    func addToList(releaseId: Int64, category: Int) async throws -> SimpleResponse {
        try await get("profile/list/add/\(category)/\(releaseId)")
    }

    /// Убрать релиз из любой категории закладок.
    @discardableResult
    func removeFromList(releaseId: Int64) async throws -> SimpleResponse {
        try await get("profile/list/delete/0/\(releaseId)")
    }

    /// Добавить/убрать в избранное (звёздочка, отдельно от 5 категорий).
    @discardableResult
    func addToFavorites(releaseId: Int64) async throws -> SimpleResponse {
        try await get("favorite/add/\(releaseId)")
    }

    @discardableResult
    func removeFromFavorites(releaseId: Int64) async throws -> SimpleResponse {
        try await get("favorite/delete/\(releaseId)")
    }

    // MARK: - Profile

    func profile(id: Int64) async throws -> Profile {
        let resp: ProfileResponse = try await get("profile/\(id)")
        guard let profile = resp.profile else { throw APIError.empty }
        return profile
    }

    // MARK: - Auth

    func signIn(login: String, password: String) async throws -> SignInResponse {
        try await post("auth/signIn", form: [
            "login": login,
            "password": password
        ])
    }
}

/// Generic response for endpoints that only return code/message.
struct SimpleResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
    }
    enum CodingKeys: String, CodingKey { case code, message }
}

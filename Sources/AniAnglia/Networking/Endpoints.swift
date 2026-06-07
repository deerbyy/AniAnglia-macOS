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

    /// "Обсуждают" from the Anixart Discover screen.
    func discoverDiscussing() async throws -> ReleasesResponse {
        try await post("discover/discussing")
    }

    /// "Комментарии недели" from the Anixart Discover screen.
    func discoverCommentsWeek() async throws -> CommentsResponse {
        try await post("discover/comments")
    }

    /// "Коллекции недели" from iOS Discover.
    func discoverWeekCollections(page: Int = 0) async throws -> CollectionsResponse {
        try await collections(page: page, scope: 2, sort: .weekPopular)
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
        try await postJSON("search/releases/\(page)", body: [
            "query": query,
            "searchBy": searchBy
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

    // MARK: - Collections

    /// Public Anixart collections. iOS uses `scope=1, sort=YearPopular` for the full collections screen.
    func collections(page: Int = 0, scope: Int = 1, sort: CollectionSort = .yearPopular) async throws -> CollectionsResponse {
        try await get("collection/all/\(page)", query: collectionPagingQuery(page: page, scope: scope, sort: sort))
    }

    func collection(id: Int64) async throws -> CollectionInfo {
        let resp: CollectionResponse = try await get("collection/\(id)")
        guard let info = resp.info else { throw APIError.server(code: resp.code, message: "Коллекция не найдена") }
        return info
    }

    func collectionReleases(collectionId: Int64, page: Int = 0) async throws -> ReleasesResponse {
        try await get("collection/\(collectionId)/releases/\(page)")
    }

    func releaseCollections(releaseId: Int64, page: Int = 0, sort: CollectionSort = .yearPopular) async throws -> CollectionsResponse {
        try await get("collection/all/release/\(releaseId)/\(page)", query: [
            URLQueryItem(name: "sort", value: String(sort.rawValue))
        ])
    }

    func favoriteCollections(page: Int = 0) async throws -> CollectionsResponse {
        try await get("collectionFavorite/all/\(page)")
    }

    @discardableResult
    func addCollectionToFavorites(collectionId: Int64) async throws -> SimpleResponse {
        try await get("collectionFavorite/add/\(collectionId)")
    }

    @discardableResult
    func removeCollectionFromFavorites(collectionId: Int64) async throws -> SimpleResponse {
        try await get("collectionFavorite/delete/\(collectionId)")
    }

    // MARK: - Bookmarks / Profile lists

    /// Список релизов в категории закладок (для текущего пользователя).
    /// Категория как в libanixart `Profile::ListStatus`: 1=Смотрю, 2=В планах, 3=Просмотрено, 4=Отложено, 5=Брошено.
    func bookmarks(category: Int, page: Int = 0, sort: ProfileListSort = .dateAddedNewest) async throws -> ReleasesResponse {
        guard let pid = auth.profileId else { throw APIError.server(code: 401, message: "Не авторизован") }
        return try await profileListReleases(profileId: pid, category: category, page: page, sort: sort)
    }

    /// Public profile list category. If the owner hides lists, the API returns an error or an empty page.
    func profileListReleases(profileId: Int64, category: Int, page: Int = 0, sort: ProfileListSort = .dateAddedNewest) async throws -> ReleasesResponse {
        try await get("profile/list/all/\(profileId)/\(category)/\(page)", query: [
            URLQueryItem(name: "sort", value: String(sort.rawValue))
        ])
    }

    func profileListReleases(profileId: Int64, category: BookmarkCategory, page: Int = 0, sort: ProfileListSort = .dateAddedNewest) async throws -> ReleasesResponse {
        try await profileListReleases(profileId: profileId, category: category.rawValue, page: page, sort: sort)
    }

    func bookmarks(category: BookmarkCategory, page: Int = 0, sort: ProfileListSort = .dateAddedNewest) async throws -> ReleasesResponse {
        try await bookmarks(category: category.rawValue, page: page, sort: sort)
    }

    /// Official Anixart list status mutation. This is the same account-backed
    /// profile list used by the Android/iOS app, so changes sync across clients.
    @discardableResult
    func setProfileListStatus(releaseId: Int64, category: BookmarkCategory?) async throws -> SimpleResponse {
        guard let category else {
            throw APIError.server(code: 400, message: "Нужно знать текущую категорию, чтобы удалить релиз из списка")
        }
        return try await addToList(releaseId: releaseId, category: category)
    }

    @discardableResult
    func setProfileListStatus(releaseId: Int64, category: Int?) async throws -> SimpleResponse {
        if let category {
            return try await setProfileListStatus(releaseId: releaseId, category: BookmarkCategory(rawValue: category))
        }
        return try await setProfileListStatus(releaseId: releaseId, category: Optional<BookmarkCategory>.none)
    }

    /// Добавить релиз в категорию (или переместить, если уже в другой).
    @discardableResult
    func addToList(releaseId: Int64, category: Int) async throws -> SimpleResponse {
        guard let category = BookmarkCategory(rawValue: category) else {
            throw APIError.server(code: 400, message: "Неизвестная категория списка")
        }
        return try await addToList(releaseId: releaseId, category: category)
    }

    @discardableResult
    func addToList(releaseId: Int64, category: BookmarkCategory) async throws -> SimpleResponse {
        try await get("profile/list/add/\(category.rawValue)/\(releaseId)")
    }

    /// Убрать релиз из конкретной категории закладок.
    @discardableResult
    func removeFromList(releaseId: Int64, category: BookmarkCategory) async throws -> SimpleResponse {
        try await get("profile/list/delete/\(category.rawValue)/\(releaseId)")
    }

    /// Best-effort removal when the current category is unknown.
    @discardableResult
    func removeFromList(releaseId: Int64) async throws -> SimpleResponse {
        var lastError: Error?
        for category in BookmarkCategory.displayOrder {
            do { return try await removeFromList(releaseId: releaseId, category: category) }
            catch { lastError = error }
        }
        throw lastError ?? APIError.empty
    }

    /// Добавить/убрать в избранное (звёздочка, отдельно от 5 категорий).
    func favorites(page: Int = 0, sort: ProfileListSort = .dateAddedNewest, filterAnnounce: Int = 0) async throws -> ReleasesResponse {
        try await get("favorite/all/\(page)", query: [
            URLQueryItem(name: "sort", value: String(sort.rawValue)),
            URLQueryItem(name: "filter_announce", value: String(filterAnnounce))
        ])
    }

    @discardableResult
    func addToFavorites(releaseId: Int64) async throws -> SimpleResponse {
        try await get("favorite/add/\(releaseId)")
    }

    @discardableResult
    func removeFromFavorites(releaseId: Int64) async throws -> SimpleResponse {
        try await get("favorite/delete/\(releaseId)")
    }

    // MARK: - Comments

    /// Comments for a release. `sort`: 0=new, 1=old, 2=top.
    func releaseComments(releaseId: Int64, page: Int, sort: Int = 2) async throws -> CommentsResponse {
        try await get("release/comment/all/\(releaseId)/\(page)", query: [URLQueryItem(name: "sort", value: String(sort))])
    }

    /// Replies for a release comment.
    func commentReplies(commentId: Int64, page: Int) async throws -> CommentsResponse {
        try await get("release/comment/replies/\(commentId)/\(page)")
    }

    /// Post a new comment to a release. `parentCommentId` is for replies.
    /// Spoiler flag marks the message as a hidden spoiler.
    func addComment(releaseId: Int64, message: String, parentCommentId: Int64? = nil, isSpoiler: Bool = false) async throws -> SimpleResponse {
        var body: [String: Any] = [
            "message": message,
            "is_spoiler": isSpoiler
        ]
        if let parentCommentId { body["parent_comment_id"] = parentCommentId }
        return try await postJSON("release/comment/add/\(releaseId)", body: body)
    }

    /// Edit one of the current user's comments.
    func editComment(commentId: Int64, message: String, isSpoiler: Bool = false) async throws -> SimpleResponse {
        try await postJSON("release/comment/edit/\(commentId)", body: [
            "message": message,
            "is_spoiler": isSpoiler
        ])
    }

    /// Delete one of the current user's comments.
    func deleteComment(commentId: Int64) async throws -> SimpleResponse {
        try await get("release/comment/delete/\(commentId)")
    }

    /// Vote on a comment. value: 1 = like, -1 = dislike, 0 = remove vote.
    func voteComment(commentId: Int64, value: Int) async throws -> SimpleResponse {
        try await get("release/comment/vote/\(commentId)/\(value)")
    }

    // MARK: - Release rating

    /// Rate a release with 1..5 stars.
    func rateRelease(releaseId: Int64, stars: Int) async throws -> SimpleResponse {
        try await get("release/vote/add/\(releaseId)/\(stars)")
    }

    /// Remove your rating from a release.
    func unrateRelease(releaseId: Int64) async throws -> SimpleResponse {
        try await get("release/vote/delete/\(releaseId)")
    }

    // MARK: - Episode tracking

    /// Mark a single episode as watched. Requires auth.
    func markEpisodeWatched(releaseId: Int64, sourceId: Int, position: Int) async throws -> SimpleResponse {
        try await get("episode/watch/\(releaseId)/\(sourceId)/\(position)")
    }

    /// Unmark an episode (removes from history).
    func unmarkEpisodeWatched(releaseId: Int64, sourceId: Int, position: Int) async throws -> SimpleResponse {
        try await get("episode/unwatch/\(releaseId)/\(sourceId)/\(position)")
    }

    // MARK: - History

    func watchHistory(page: Int) async throws -> ReleasesResponse {
        try await get("history/\(page)")
    }

    // MARK: - Profile

    func profile(id: Int64) async throws -> Profile {
        let resp: ProfileResponse = try await get("profile/\(id)")
        guard let profile = resp.profile else { throw APIError.empty }
        return profile
    }

    func profileFriends(profileId: Int64, page: Int = 0) async throws -> ProfilesResponse {
        try await get("profile/friend/all/\(profileId)/\(page)")
    }

    func friendRequests(scope: FriendRequestScope, page: Int = 0) async throws -> ProfilesResponse {
        try await get("profile/friend/requests/\(scope.rawValue)/\(page)")
    }

    func latestFriendRequests(scope: FriendRequestScope) async throws -> ProfilesResponse {
        try await get("profile/friend/requests/\(scope.rawValue)/last")
    }

    @discardableResult
    func sendFriendRequest(profileId: Int64) async throws -> SimpleResponse {
        try await get("profile/friend/request/send/\(profileId)")
    }

    @discardableResult
    func removeFriendRequest(profileId: Int64) async throws -> SimpleResponse {
        try await get("profile/friend/request/remove/\(profileId)")
    }

    @discardableResult
    func hideFriendRequest(profileId: Int64) async throws -> SimpleResponse {
        try await get("profile/friend/request/hide/\(profileId)")
    }

    // MARK: - Auth

    func signIn(login: String, password: String) async throws -> SignInResponse {
        try await post("auth/signIn", form: [
            "login": login,
            "password": password
        ])
    }

    private func collectionPagingQuery(page: Int, scope: Int, sort: CollectionSort) -> [URLQueryItem] {
        [
            URLQueryItem(name: "previous_page", value: String(max(0, page - 1))),
            URLQueryItem(name: "where", value: String(scope)),
            URLQueryItem(name: "sort", value: String(sort.rawValue))
        ]
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

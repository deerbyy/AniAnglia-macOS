import Foundation

enum CollectionSort: Int, CaseIterable, Identifiable, Hashable {
    case ratingLeader = 1
    case yearPopular = 2
    case seasonPopular = 3
    case weekPopular = 4
    case recentlyAdded = 5
    case random = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .ratingLeader: return "По рейтингу"
        case .yearPopular: return "Популярные за год"
        case .seasonPopular: return "Популярные сезона"
        case .weekPopular: return "Популярные недели"
        case .recentlyAdded: return "Недавно добавленные"
        case .random: return "Случайные"
        }
    }
}

struct AnixartCollection: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let description: String?
    let creator: Profile?
    let imageURLString: String?
    let lastUpdateDate: Int64?
    let creationDate: Int64?
    let releases: [Release]
    let commentCount: Int?
    let favoriteCount: Int?
    let isFavorite: Bool?
    let isPrivate: Bool?

    var imageURL: URL? {
        imageURLString.flatMap { URL(string: $0) }
    }

    var displayDescription: String {
        guard let description, !description.isEmpty else { return "Описание отсутствует" }
        return description
    }

    init(
        id: Int64,
        title: String,
        description: String?,
        creator: Profile?,
        imageURLString: String?,
        lastUpdateDate: Int64?,
        creationDate: Int64?,
        releases: [Release],
        commentCount: Int?,
        favoriteCount: Int?,
        isFavorite: Bool?,
        isPrivate: Bool?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.creator = creator
        self.imageURLString = imageURLString
        self.lastUpdateDate = lastUpdateDate
        self.creationDate = creationDate
        self.releases = releases
        self.commentCount = commentCount
        self.favoriteCount = favoriteCount
        self.isFavorite = isFavorite
        self.isPrivate = isPrivate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ReleaseCodingKey.self)
        id = c.decodeInt64("id") ?? c.decodeInt64("collection_id") ?? 0
        title = c.decodeString("title") ?? c.decodeString("name") ?? "Коллекция #\(id)"
        description = c.decodeString("description")
        creator = try? c.decodeIfPresent(Profile.self, forKey: "creator")
        imageURLString = c.decodeString("image_url") ?? c.decodeString("imageUrl") ?? c.decodeString("image")
        lastUpdateDate = c.decodeInt64("last_update_date") ?? c.decodeInt64("lastUpdateDate")
        creationDate = c.decodeInt64("creation_date") ?? c.decodeInt64("creationDate")
        releases = (try? c.decodeIfPresent([Release].self, forKey: "releases")) ?? []
        commentCount = c.decodeInt("comment_count") ?? c.decodeInt("commentCount")
        favoriteCount = c.decodeInt("favorite_count") ?? c.decodeInt("favorites_count") ?? c.decodeInt("favoriteCount") ?? c.decodeInt("favoritesCount")
        isFavorite = c.decodeBool("is_favorite") ?? c.decodeBool("isFavorite")
        isPrivate = c.decodeBool("is_private") ?? c.decodeBool("isPrivate")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ReleaseCodingKey.self)
        try c.encode(id, forKey: "id")
        try c.encode(title, forKey: "title")
        try c.encodeIfPresent(description, forKey: "description")
        try c.encodeIfPresent(creator, forKey: "creator")
        try c.encodeIfPresent(imageURLString, forKey: "image_url")
        try c.encodeIfPresent(lastUpdateDate, forKey: "last_update_date")
        try c.encodeIfPresent(creationDate, forKey: "creation_date")
        try c.encode(releases, forKey: "releases")
        try c.encodeIfPresent(commentCount, forKey: "comment_count")
        try c.encodeIfPresent(favoriteCount, forKey: "favorite_count")
        try c.encodeIfPresent(isFavorite, forKey: "is_favorite")
        try c.encodeIfPresent(isPrivate, forKey: "is_private")
    }

    func withFavorite(_ favorite: Bool?) -> AnixartCollection {
        AnixartCollection(
            id: id,
            title: title,
            description: description,
            creator: creator,
            imageURLString: imageURLString,
            lastUpdateDate: lastUpdateDate,
            creationDate: creationDate,
            releases: releases,
            commentCount: commentCount,
            favoriteCount: favoriteCount,
            isFavorite: favorite,
            isPrivate: isPrivate
        )
    }

    func matchesLibraryQuery(_ query: String) -> Bool {
        let needle = query.normalizedLibrarySearchQuery
        guard !needle.isEmpty else { return true }
        return [
            title,
            description,
            creator?.displayName,
            creationDate.map(String.init),
            lastUpdateDate.map(String.init)
        ]
        .compactMap { $0?.normalizedLibrarySearchQuery }
        .contains { $0.contains(needle) }
    }

    static func == (lhs: AnixartCollection, rhs: AnixartCollection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CollectionRoute: Hashable, Identifiable {
    let id: Int64
    let title: String
    let description: String?
    let imageURLString: String?
    let isFavorite: Bool?

    init(_ collection: AnixartCollection) {
        id = collection.id
        title = collection.title
        description = collection.description
        imageURLString = collection.imageURLString
        isFavorite = collection.isFavorite
    }

    init(_ collection: CommentCollection) {
        id = collection.id
        title = collection.displayTitle
        description = nil
        imageURLString = nil
        isFavorite = nil
    }

    var prefetchedCollection: AnixartCollection {
        AnixartCollection(
            id: id,
            title: title,
            description: description,
            creator: nil,
            imageURLString: imageURLString,
            lastUpdateDate: nil,
            creationDate: nil,
            releases: [],
            commentCount: nil,
            favoriteCount: nil,
            isFavorite: isFavorite,
            isPrivate: nil
        )
    }
}

struct CollectionInfo: Codable, Hashable {
    let collection: AnixartCollection
    let watchedCount: Int?
    let droppedCount: Int?
    let holdOnCount: Int?
    let planCount: Int?
    let watchingCount: Int?
}

struct CollectionResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let collection: AnixartCollection?
    let watchedCount: Int?
    let droppedCount: Int?
    let holdOnCount: Int?
    let planCount: Int?
    let watchingCount: Int?

    var info: CollectionInfo? {
        guard let collection else { return nil }
        return CollectionInfo(
            collection: collection,
            watchedCount: watchedCount,
            droppedCount: droppedCount,
            holdOnCount: holdOnCount,
            planCount: planCount,
            watchingCount: watchingCount
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ReleaseCodingKey.self)
        code = c.decodeInt("code") ?? 0
        message = c.decodeString("message")
        collection = try? c.decodeIfPresent(AnixartCollection.self, forKey: "collection")
        watchedCount = c.decodeInt("watched_count") ?? c.decodeInt("completed_count") ?? c.decodeInt("watchedCount") ?? c.decodeInt("completedCount")
        droppedCount = c.decodeInt("dropped_count") ?? c.decodeInt("droppedCount")
        holdOnCount = c.decodeInt("hold_on_count") ?? c.decodeInt("holdOnCount")
        planCount = c.decodeInt("plan_count") ?? c.decodeInt("planCount")
        watchingCount = c.decodeInt("watching_count") ?? c.decodeInt("watchingCount")
    }
}

struct CollectionsResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let collections: [AnixartCollection]
    let content: [AnixartCollection]
    let totalCount: Int?
    let totalPageCount: Int?
    let currentPage: Int?

    var items: [AnixartCollection] { collections.isEmpty ? content : collections }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ReleaseCodingKey.self)
        code = c.decodeInt("code") ?? 0
        message = c.decodeString("message")
        collections = (try? c.decodeIfPresent([AnixartCollection].self, forKey: "collections")) ?? []
        content = (try? c.decodeIfPresent([AnixartCollection].self, forKey: "content")) ?? []
        totalCount = c.decodeInt("total_count") ?? c.decodeInt("totalCount")
        totalPageCount = c.decodeInt("total_page_count") ?? c.decodeInt("totalPageCount")
        currentPage = c.decodeInt("current_page") ?? c.decodeInt("currentPage")
    }
}

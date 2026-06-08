import Foundation

struct CommentProfile: Codable, Hashable {
    let id: Int64
    let login: String?
    let avatar: String?

    var avatarURL: URL? { avatar.flatMap { URL(string: $0) } }
    var displayName: String { login ?? "Профиль #\(id)" }

    init(id: Int64, login: String?, avatar: String?) {
        self.id = id
        self.login = login
        self.avatar = avatar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CommentCodingKey.self)
        id = c.decodeInt64("id") ?? c.decodeInt64("profile_id") ?? 0
        login = c.decodeString("login") ?? c.decodeString("username") ?? c.decodeString("nickname") ?? c.decodeString("name")
        avatar = c.decodeString("avatar") ?? c.decodeString("avatar_url") ?? c.decodeString("image") ?? c.decodeString("image_url")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CommentCodingKey.self)
        try c.encode(id, forKey: "id")
        try c.encodeIfPresent(login, forKey: "username")
        try c.encodeIfPresent(avatar, forKey: "avatar_url")
    }
}

struct CommentCollection: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String?

    var displayTitle: String { title ?? "Коллекция #\(id)" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CommentCodingKey.self)
        id = c.decodeInt64("id") ?? c.decodeInt64("collection_id") ?? 0
        title = c.decodeString("title") ?? c.decodeString("name")
    }
}

struct ReleaseComment: Codable, Identifiable, Hashable {
    let id: Int64
    let message: String
    let timestamp: Int64?
    let likesCount: Int?
    let voteCount: Int?
    let vote: Int?
    let isEdited: Bool?
    let isDeleted: Bool?
    let isReply: Bool?
    let isSpoiler: Bool?
    let replyCount: Int?
    let parentCommentId: Int64?
    let postedAtEpisode: Int?
    let profile: CommentProfile?
    let release: Release?
    let collection: CommentCollection?

    var formattedDate: String {
        guard let ts = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    var originTitle: String? {
        if let release { return "к релизу: \(release.displayTitle)" }
        if let collection { return "к коллекции: \(collection.displayTitle)" }
        return nil
    }

    init(
        id: Int64,
        message: String,
        timestamp: Int64?,
        likesCount: Int?,
        voteCount: Int?,
        vote: Int?,
        isEdited: Bool?,
        isDeleted: Bool?,
        isReply: Bool?,
        isSpoiler: Bool?,
        replyCount: Int?,
        parentCommentId: Int64?,
        postedAtEpisode: Int?,
        profile: CommentProfile?,
        release: Release?,
        collection: CommentCollection?
    ) {
        self.id = id
        self.message = message
        self.timestamp = timestamp
        self.likesCount = likesCount
        self.voteCount = voteCount
        self.vote = vote
        self.isEdited = isEdited
        self.isDeleted = isDeleted
        self.isReply = isReply
        self.isSpoiler = isSpoiler
        self.replyCount = replyCount
        self.parentCommentId = parentCommentId
        self.postedAtEpisode = postedAtEpisode
        self.profile = profile
        self.release = release
        self.collection = collection
    }

    func edited(message: String, isSpoiler: Bool) -> ReleaseComment {
        ReleaseComment(
            id: id,
            message: message,
            timestamp: timestamp,
            likesCount: likesCount,
            voteCount: voteCount,
            vote: vote,
            isEdited: true,
            isDeleted: isDeleted,
            isReply: isReply,
            isSpoiler: isSpoiler,
            replyCount: replyCount,
            parentCommentId: parentCommentId,
            postedAtEpisode: postedAtEpisode,
            profile: profile,
            release: release,
            collection: collection
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CommentCodingKey.self)
        id = c.decodeInt64("id") ?? 0
        message = c.decodeString("message") ?? ""
        timestamp = c.decodeInt64("timestamp") ?? c.decodeInt64("date") ?? c.decodeInt64("created_at") ?? c.decodeInt64("createdAt")
        likesCount = c.decodeInt("likes_count") ?? c.decodeInt("likesCount")
        voteCount = c.decodeInt("vote_count") ?? c.decodeInt("voteCount") ?? likesCount
        vote = c.decodeInt("vote")
        isEdited = c.decodeBool("is_edited") ?? c.decodeBool("isEdited")
        isDeleted = c.decodeBool("is_deleted") ?? c.decodeBool("isDeleted")
        isReply = c.decodeBool("is_reply") ?? c.decodeBool("isReply")
        isSpoiler = c.decodeBool("is_spoiler") ?? c.decodeBool("isSpoiler")
        replyCount = c.decodeInt("reply_count") ?? c.decodeInt("replyCount")
        parentCommentId = c.decodeInt64("parent_comment_id") ?? c.decodeInt64("parentCommentId")
        postedAtEpisode = c.decodeInt("posted_at_episode") ?? c.decodeInt("postedAtEpisode")
        profile = (try? c.decodeIfPresent(CommentProfile.self, forKey: "profile"))
            ?? (try? c.decodeIfPresent(CommentProfile.self, forKey: "author"))
        release = try? c.decodeIfPresent(Release.self, forKey: "release")
        collection = try? c.decodeIfPresent(CommentCollection.self, forKey: "collection")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CommentCodingKey.self)
        try c.encode(id, forKey: "id")
        try c.encode(message, forKey: "message")
        try c.encodeIfPresent(timestamp, forKey: "date")
        try c.encodeIfPresent(likesCount, forKey: "likes_count")
        try c.encodeIfPresent(voteCount, forKey: "vote_count")
        try c.encodeIfPresent(vote, forKey: "vote")
        try c.encodeIfPresent(isEdited, forKey: "is_edited")
        try c.encodeIfPresent(isDeleted, forKey: "is_deleted")
        try c.encodeIfPresent(isReply, forKey: "is_reply")
        try c.encodeIfPresent(isSpoiler, forKey: "is_spoiler")
        try c.encodeIfPresent(replyCount, forKey: "reply_count")
        try c.encodeIfPresent(parentCommentId, forKey: "parent_comment_id")
        try c.encodeIfPresent(postedAtEpisode, forKey: "posted_at_episode")
        try c.encodeIfPresent(profile, forKey: "author")
        try c.encodeIfPresent(release, forKey: "release")
        try c.encodeIfPresent(collection, forKey: "collection")
    }
}

extension ReleaseComment {
    func matchesCommentQuery(_ query: String) -> Bool {
        let needle = query.normalizedLibrarySearchQuery
        guard !needle.isEmpty else { return true }
        let values = [
            message,
            formattedDate,
            originTitle,
            profile?.displayName,
            release?.displayTitle,
            collection?.displayTitle,
            postedAtEpisode.map(String.init)
        ]
        let textMatches = values
            .compactMap { $0?.normalizedLibrarySearchQuery }
            .contains { $0.contains(needle) }
        return textMatches || release?.matchesLibraryQuery(query) == true
    }
}

struct CommentsResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let content: [ReleaseComment]
    let totalCount: Int?
    let totalPageCount: Int?
    let currentPage: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.content = (try? c.decode([ReleaseComment].self, forKey: .content)) ?? []
        self.totalCount = try? c.decode(Int.self, forKey: .totalCount)
        self.totalPageCount = try? c.decode(Int.self, forKey: .totalPageCount)
        self.currentPage = try? c.decode(Int.self, forKey: .currentPage)
    }

    enum CodingKeys: String, CodingKey {
        case code, message, content, totalCount, totalPageCount, currentPage
    }
}

struct CommentCodingKey: CodingKey, ExpressibleByStringLiteral {
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

extension KeyedEncodingContainer where Key == CommentCodingKey {
    mutating func encode<T: Encodable>(_ value: T, forKey key: String) throws {
        try encode(value, forKey: CommentCodingKey(key))
    }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: String) throws {
        try encodeIfPresent(value, forKey: CommentCodingKey(key))
    }
}

extension KeyedDecodingContainer where Key == CommentCodingKey {
    func decodeString(_ key: String) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: CommentCodingKey(key)), !value.isEmpty {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: CommentCodingKey(key)) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: CommentCodingKey(key)) {
            return String(value)
        }
        return nil
    }

    func decodeInt(_ key: String) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: CommentCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: CommentCodingKey(key)) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: CommentCodingKey(key)) {
            return Int(value)
        }
        return nil
    }

    func decodeInt64(_ key: String) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: CommentCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: CommentCodingKey(key)) {
            return Int64(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: CommentCodingKey(key)) {
            return Int64(value)
        }
        return nil
    }

    func decodeBool(_ key: String) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: CommentCodingKey(key)) {
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
}

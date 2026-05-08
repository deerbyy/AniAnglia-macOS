import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: Int64
    let login: String?
    let avatar: String?
    let status: String?
    let telegramPage: String?
    let vkPage: String?
    let instagramPage: String?
    let discordPage: String?
    let tiktokPage: String?
    let lastActivityTime: Int64?
    let registerDate: Int64?
    let watchedReleasesCount: Int?
    let plannedReleasesCount: Int?
    let watchingReleasesCount: Int?
    let abandonedReleasesCount: Int?
    let holdOnReleasesCount: Int?
    let favoriteCount: Int?
    let videoCount: Int?
    let watchedEpisodeCount: Int?
    let commentCount: Int?
    let collectionCount: Int?
    let ratingScore: Int?
    let friendCount: Int?
    let watchedTimeMinutes: Int?
    let isOnline: Bool?
    let isVerified: Bool?
    let isSponsor: Bool?
    let isStatsHidden: Bool?
    let isCountsHidden: Bool?
    let roles: [ProfileRole]
    let votes: [Release]
    let history: [Release]
    let watchDynamics: [ProfileWatchDynamic]
    let collectionsPreview: [AnixartCollection]
    let commentsPreview: [ReleaseComment]
    let releaseCommentsPreview: [ReleaseComment]
    let releaseVideosPreview: [Video]

    var avatarURL: URL? {
        avatar.flatMap { URL(string: $0) }
    }

    var displayName: String {
        login ?? "Профиль #\(id)"
    }

    var watchedTimeText: String? {
        guard let minutes = watchedTimeMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let tailMinutes = minutes % 60
        if hours > 0 {
            return "\(hours) ч \(tailMinutes) мин"
        }
        return "\(tailMinutes) мин"
    }

    var socialLinks: [(title: String, value: String)] {
        [
            ("Telegram", telegramPage),
            ("VK", vkPage),
            ("Instagram", instagramPage),
            ("Discord", discordPage),
            ("TikTok", tiktokPage)
        ].compactMap { title, value in
            guard let value, !value.isEmpty else { return nil }
            return (title, value)
        }
    }

    init(
        id: Int64,
        login: String?,
        avatar: String?,
        status: String?,
        telegramPage: String? = nil,
        vkPage: String? = nil,
        instagramPage: String? = nil,
        discordPage: String? = nil,
        tiktokPage: String? = nil,
        lastActivityTime: Int64? = nil,
        registerDate: Int64? = nil,
        watchedReleasesCount: Int? = nil,
        plannedReleasesCount: Int? = nil,
        watchingReleasesCount: Int? = nil,
        abandonedReleasesCount: Int? = nil,
        holdOnReleasesCount: Int? = nil,
        favoriteCount: Int? = nil,
        videoCount: Int? = nil,
        watchedEpisodeCount: Int? = nil,
        commentCount: Int? = nil,
        collectionCount: Int? = nil,
        ratingScore: Int? = nil,
        friendCount: Int? = nil,
        watchedTimeMinutes: Int? = nil,
        isOnline: Bool? = nil,
        isVerified: Bool? = nil,
        isSponsor: Bool? = nil,
        isStatsHidden: Bool? = nil,
        isCountsHidden: Bool? = nil,
        roles: [ProfileRole] = [],
        votes: [Release] = [],
        history: [Release] = [],
        watchDynamics: [ProfileWatchDynamic] = [],
        collectionsPreview: [AnixartCollection] = [],
        commentsPreview: [ReleaseComment] = [],
        releaseCommentsPreview: [ReleaseComment] = [],
        releaseVideosPreview: [Video] = []
    ) {
        self.id = id
        self.login = login
        self.avatar = avatar
        self.status = status
        self.telegramPage = telegramPage
        self.vkPage = vkPage
        self.instagramPage = instagramPage
        self.discordPage = discordPage
        self.tiktokPage = tiktokPage
        self.lastActivityTime = lastActivityTime
        self.registerDate = registerDate
        self.watchedReleasesCount = watchedReleasesCount
        self.plannedReleasesCount = plannedReleasesCount
        self.watchingReleasesCount = watchingReleasesCount
        self.abandonedReleasesCount = abandonedReleasesCount
        self.holdOnReleasesCount = holdOnReleasesCount
        self.favoriteCount = favoriteCount
        self.videoCount = videoCount
        self.watchedEpisodeCount = watchedEpisodeCount
        self.commentCount = commentCount
        self.collectionCount = collectionCount
        self.ratingScore = ratingScore
        self.friendCount = friendCount
        self.watchedTimeMinutes = watchedTimeMinutes
        self.isOnline = isOnline
        self.isVerified = isVerified
        self.isSponsor = isSponsor
        self.isStatsHidden = isStatsHidden
        self.isCountsHidden = isCountsHidden
        self.roles = roles
        self.votes = votes
        self.history = history
        self.watchDynamics = watchDynamics
        self.collectionsPreview = collectionsPreview
        self.commentsPreview = commentsPreview
        self.releaseCommentsPreview = releaseCommentsPreview
        self.releaseVideosPreview = releaseVideosPreview
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ProfileCodingKey.self)
        id = c.decodeInt64("id") ?? c.decodeInt64("profile_id") ?? 0
        login = c.decodeString("login") ?? c.decodeString("username") ?? c.decodeString("nickname") ?? c.decodeString("name")
        avatar = c.decodeString("avatar") ?? c.decodeString("avatar_url") ?? c.decodeString("image") ?? c.decodeString("image_url")
        status = c.decodeString("status")
        telegramPage = c.decodeString("telegram_page") ?? c.decodeString("tg_page")
        vkPage = c.decodeString("vk_page")
        instagramPage = c.decodeString("instagram_page")
        discordPage = c.decodeString("discord_page")
        tiktokPage = c.decodeString("tt_page") ?? c.decodeString("tiktok_page")
        lastActivityTime = c.decodeInt64("last_activity_time")
        registerDate = c.decodeInt64("register_date")
        watchedReleasesCount = c.decodeInt("watched_releases_count") ?? c.decodeInt("watched_count")
        plannedReleasesCount = c.decodeInt("planned_releases_count") ?? c.decodeInt("plan_count") ?? c.decodeInt("planned_count")
        watchingReleasesCount = c.decodeInt("watching_releases_count") ?? c.decodeInt("watching_count")
        abandonedReleasesCount = c.decodeInt("abandoned_releases_count") ?? c.decodeInt("dropped_count") ?? c.decodeInt("abandoned_count")
        holdOnReleasesCount = c.decodeInt("hold_on_releases_count") ?? c.decodeInt("hold_on_count")
        favoriteCount = c.decodeInt("favorite_count") ?? c.decodeInt("favorites_count")
        videoCount = c.decodeInt("video_count")
        watchedEpisodeCount = c.decodeInt("watched_episode_count")
        commentCount = c.decodeInt("comment_count")
        collectionCount = c.decodeInt("collection_count")
        ratingScore = c.decodeInt("rating_score")
        friendCount = c.decodeInt("friend_count")
        watchedTimeMinutes = c.decodeInt("watched_time")
        isOnline = c.decodeBool("is_online")
        isVerified = c.decodeBool("is_verified")
        isSponsor = c.decodeBool("is_sponsor")
        isStatsHidden = c.decodeBool("is_stats_hidden")
        isCountsHidden = c.decodeBool("is_counts_hidden")
        roles = (try? c.decodeIfPresent([ProfileRole].self, forKey: ProfileCodingKey("roles"))) ?? []
        votes = (try? c.decodeIfPresent([Release].self, forKey: ProfileCodingKey("votes"))) ?? []
        history = (try? c.decodeIfPresent([Release].self, forKey: ProfileCodingKey("history"))) ?? []
        watchDynamics = (try? c.decodeIfPresent([ProfileWatchDynamic].self, forKey: ProfileCodingKey("watch_dynamics")))
            ?? (try? c.decodeIfPresent([ProfileWatchDynamic].self, forKey: ProfileCodingKey("watchDynamics")))
            ?? []
        collectionsPreview = (try? c.decodeIfPresent([AnixartCollection].self, forKey: ProfileCodingKey("collections_preview")))
            ?? (try? c.decodeIfPresent([AnixartCollection].self, forKey: ProfileCodingKey("collectionsPreview")))
            ?? []
        commentsPreview = (try? c.decodeIfPresent([ReleaseComment].self, forKey: ProfileCodingKey("comments_preview")))
            ?? (try? c.decodeIfPresent([ReleaseComment].self, forKey: ProfileCodingKey("commentsPreview")))
            ?? []
        releaseCommentsPreview = (try? c.decodeIfPresent([ReleaseComment].self, forKey: ProfileCodingKey("release_comments_preview")))
            ?? (try? c.decodeIfPresent([ReleaseComment].self, forKey: ProfileCodingKey("releaseCommentsPreview")))
            ?? []
        releaseVideosPreview = (try? c.decodeIfPresent([Video].self, forKey: ProfileCodingKey("release_videos_preview")))
            ?? (try? c.decodeIfPresent([Video].self, forKey: ProfileCodingKey("releaseVideosPreview")))
            ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ProfileCodingKey.self)
        try c.encode(id, forKey: ProfileCodingKey("id"))
        try c.encodeIfPresent(login, forKey: ProfileCodingKey("username"))
        try c.encodeIfPresent(avatar, forKey: ProfileCodingKey("avatar_url"))
        try c.encodeIfPresent(status, forKey: ProfileCodingKey("status"))
        try c.encodeIfPresent(telegramPage, forKey: ProfileCodingKey("telegram_page"))
        try c.encodeIfPresent(vkPage, forKey: ProfileCodingKey("vk_page"))
        try c.encodeIfPresent(instagramPage, forKey: ProfileCodingKey("instagram_page"))
        try c.encodeIfPresent(discordPage, forKey: ProfileCodingKey("discord_page"))
        try c.encodeIfPresent(tiktokPage, forKey: ProfileCodingKey("tt_page"))
        try c.encodeIfPresent(lastActivityTime, forKey: ProfileCodingKey("last_activity_time"))
        try c.encodeIfPresent(registerDate, forKey: ProfileCodingKey("register_date"))
        try c.encodeIfPresent(watchedReleasesCount, forKey: ProfileCodingKey("watched_count"))
        try c.encodeIfPresent(plannedReleasesCount, forKey: ProfileCodingKey("plan_count"))
        try c.encodeIfPresent(watchingReleasesCount, forKey: ProfileCodingKey("watching_count"))
        try c.encodeIfPresent(abandonedReleasesCount, forKey: ProfileCodingKey("dropped_count"))
        try c.encodeIfPresent(holdOnReleasesCount, forKey: ProfileCodingKey("hold_on_count"))
        try c.encodeIfPresent(favoriteCount, forKey: ProfileCodingKey("favorite_count"))
        try c.encodeIfPresent(videoCount, forKey: ProfileCodingKey("video_count"))
        try c.encodeIfPresent(watchedEpisodeCount, forKey: ProfileCodingKey("watched_episode_count"))
        try c.encodeIfPresent(commentCount, forKey: ProfileCodingKey("comment_count"))
        try c.encodeIfPresent(collectionCount, forKey: ProfileCodingKey("collection_count"))
        try c.encodeIfPresent(ratingScore, forKey: ProfileCodingKey("rating_score"))
        try c.encodeIfPresent(friendCount, forKey: ProfileCodingKey("friend_count"))
        try c.encodeIfPresent(watchedTimeMinutes, forKey: ProfileCodingKey("watched_time"))
        try c.encodeIfPresent(isOnline, forKey: ProfileCodingKey("is_online"))
        try c.encodeIfPresent(isVerified, forKey: ProfileCodingKey("is_verified"))
        try c.encodeIfPresent(isSponsor, forKey: ProfileCodingKey("is_sponsor"))
        try c.encodeIfPresent(isStatsHidden, forKey: ProfileCodingKey("is_stats_hidden"))
        try c.encodeIfPresent(isCountsHidden, forKey: ProfileCodingKey("is_counts_hidden"))
        if !roles.isEmpty { try c.encode(roles, forKey: ProfileCodingKey("roles")) }
        if !votes.isEmpty { try c.encode(votes, forKey: ProfileCodingKey("votes")) }
        if !history.isEmpty { try c.encode(history, forKey: ProfileCodingKey("history")) }
        if !watchDynamics.isEmpty { try c.encode(watchDynamics, forKey: ProfileCodingKey("watch_dynamics")) }
        if !collectionsPreview.isEmpty { try c.encode(collectionsPreview, forKey: ProfileCodingKey("collections_preview")) }
        if !commentsPreview.isEmpty { try c.encode(commentsPreview, forKey: ProfileCodingKey("comments_preview")) }
        if !releaseCommentsPreview.isEmpty { try c.encode(releaseCommentsPreview, forKey: ProfileCodingKey("release_comments_preview")) }
        if !releaseVideosPreview.isEmpty { try c.encode(releaseVideosPreview, forKey: ProfileCodingKey("release_videos_preview")) }
    }
}

struct ProfileRole: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let color: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ProfileCodingKey.self)
        id = c.decodeInt64("id") ?? c.decodeInt64("role_id") ?? 0
        name = c.decodeString("name") ?? c.decodeString("title") ?? "Роль"
        color = c.decodeString("color") ?? c.decodeString("hex_color")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ProfileCodingKey.self)
        try c.encode(id, forKey: ProfileCodingKey("id"))
        try c.encode(name, forKey: ProfileCodingKey("name"))
        try c.encodeIfPresent(color, forKey: ProfileCodingKey("color"))
    }
}

struct ProfileWatchDynamic: Codable, Identifiable, Hashable {
    let id: Int64
    let day: Int?
    let watchedCount: Int
    let date: Int64?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ProfileCodingKey.self)
        id = c.decodeInt64("id")
            ?? c.decodeInt64("watch_dynamic_id")
            ?? c.decodeInt64("date")
            ?? c.decodeInt("day").map(Int64.init)
            ?? 0
        day = c.decodeInt("day")
        watchedCount = c.decodeInt("watched_count") ?? c.decodeInt("count") ?? 0
        date = c.decodeInt64("date") ?? c.decodeInt64("timestamp")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ProfileCodingKey.self)
        try c.encode(id, forKey: ProfileCodingKey("id"))
        try c.encodeIfPresent(day, forKey: ProfileCodingKey("day"))
        try c.encode(watchedCount, forKey: ProfileCodingKey("watched_count"))
        try c.encodeIfPresent(date, forKey: ProfileCodingKey("date"))
    }

    var shortDateText: String {
        if let date, date > 0 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
        }
        if let day {
            return "\(day)"
        }
        return ""
    }
}

struct ProfileResponse: Decodable, CodedResponse {
    let code: Int
    let message: String?
    let profile: Profile?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.profile = try? c.decode(Profile.self, forKey: .profile)
    }

    enum CodingKeys: String, CodingKey { case code, message, profile }
}

struct SignInResponse: Decodable, CodedResponse {
    let code: Int
    let message: String?
    let profileToken: ProfileToken?
    let profile: Profile?
    let profileId: Int64?

    enum CodingKeys: String, CodingKey {
        case code, message, profile
        case profileToken = "profileToken"
        case profileId = "profileId"
        case profile_token
        case profile_id
        case token
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedProfile = try? c.decode(Profile.self, forKey: .profile)
        let decodedProfileId = (try? c.decode(Int64.self, forKey: .profileId))
            ?? (try? c.decode(Int64.self, forKey: .profile_id))
            ?? decodedProfile?.id
        let decodedProfileToken: ProfileToken?

        if let tokenObject = try? c.decode(ProfileToken.self, forKey: .profileToken) {
            decodedProfileToken = tokenObject
        } else if let tokenObject = try? c.decode(ProfileToken.self, forKey: .profile_token) {
            decodedProfileToken = tokenObject
        } else {
            let token = (try? c.decode(String.self, forKey: .profileToken))
                ?? (try? c.decode(String.self, forKey: .profile_token))
                ?? (try? c.decode(String.self, forKey: .token))
            decodedProfileToken = token.map { ProfileToken(id: decodedProfileId, token: $0, sign: nil) }
        }

        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.profile = decodedProfile
        self.profileId = decodedProfileId
        self.profileToken = decodedProfileToken
    }
}

struct ProfileToken: Codable, Hashable {
    let id: Int64?
    let token: String?
    let sign: String?
}

struct ProfileCodingKey: CodingKey, ExpressibleByStringLiteral {
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

extension KeyedDecodingContainer where Key == ProfileCodingKey {
    func decodeString(_ key: String) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: ProfileCodingKey(key)), !value.isEmpty {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: ProfileCodingKey(key)) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: ProfileCodingKey(key)) {
            return String(value)
        }
        return nil
    }

    func decodeInt(_ key: String) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: ProfileCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: ProfileCodingKey(key)) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: ProfileCodingKey(key)) {
            return Int(value)
        }
        return nil
    }

    func decodeInt64(_ key: String) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: ProfileCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: ProfileCodingKey(key)) {
            return Int64(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: ProfileCodingKey(key)) {
            return Int64(value)
        }
        return nil
    }

    func decodeBool(_ key: String) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: ProfileCodingKey(key)) {
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

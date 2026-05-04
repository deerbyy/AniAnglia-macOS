import Foundation

struct CommentProfile: Codable, Hashable {
    let id: Int64
    let login: String?
    let avatar: String?

    var avatarURL: URL? { avatar.flatMap { URL(string: $0) } }
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

    var formattedDate: String {
        guard let ts = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
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

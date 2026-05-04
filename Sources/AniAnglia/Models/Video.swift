import Foundation

struct VideoBlock: Codable, Identifiable, Hashable {
    let category: VideoCategory
    let videos: [Video]

    var id: Int { category.id }
}

struct VideoCategory: Codable, Hashable {
    let id: Int
    let name: String
}

struct Video: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String?
    let image: String?
    let url: String?
    let playerUrl: String?
    let hosting: VideoHosting?

    enum CodingKeys: String, CodingKey {
        case id, title, image, url, hosting
        case playerUrl = "player_url"
    }

    var thumbnailURL: URL? {
        image.flatMap { URL(string: $0) }
    }

    /// Player URL with http→https conversion (avoid mixed-content / ATS).
    var resolvedPlayerURL: URL? {
        guard let raw = playerUrl ?? url, !raw.isEmpty else { return nil }
        var s = raw
        if s.hasPrefix("//") { s = "https:" + s }
        if s.hasPrefix("http://") { s = "https://" + s.dropFirst("http://".count) }
        return URL(string: s)
    }
}

struct VideoHosting: Codable, Hashable {
    let id: Int?
    let name: String?
}

struct VideoBlocksResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let blocks: [VideoBlock]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.blocks = (try? c.decode([VideoBlock].self, forKey: .blocks)) ?? []
    }

    enum CodingKeys: String, CodingKey { case code, message, blocks }
}

import Foundation

// NOTE: JSONDecoder uses .convertFromSnakeCase, so JSON keys like "is_watched"
// are automatically mapped to property "isWatched". We DO NOT add explicit
// CodingKey overrides for snake_case fields — that would break decoding because
// the strategy renames the key before lookup.

struct EpisodeType: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String?
    let workers: String?
    let isSub: Bool?
    let episodesCount: Int?
    let viewCount: Int?
    let pinned: Bool?

    var iconURL: URL? { icon.flatMap { URL(string: $0) } }
}

struct EpisodeSource: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let episodesCount: Int?
    let pinned: Bool?
}

struct Episode: Codable, Identifiable, Hashable {
    let releaseId: Int64
    let sourceId: Int
    let position: Int
    let name: String?
    let url: String?
    let iframe: Bool?
    let isWatched: Bool?

    var id: String { "\(releaseId)-\(sourceId)-\(position)" }

    /// Resolve playable URL (http→https, // schemeless).
    var resolvedURL: URL? {
        guard let raw = url, !raw.isEmpty else { return nil }
        var s = raw
        if s.hasPrefix("//") { s = "https:" + s }
        if s.hasPrefix("http://") { s = "https://" + s.dropFirst("http://".count) }
        return URL(string: s)
    }
}

struct EpisodeTypesResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let types: [EpisodeType]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.types = (try? c.decode([EpisodeType].self, forKey: .types)) ?? []
    }
    enum CodingKeys: String, CodingKey { case code, message, types }
}

struct EpisodeSourcesResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let sources: [EpisodeSource]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.sources = (try? c.decode([EpisodeSource].self, forKey: .sources)) ?? []
    }
    enum CodingKeys: String, CodingKey { case code, message, sources }
}

struct EpisodesResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let episodes: [Episode]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.episodes = (try? c.decode([Episode].self, forKey: .episodes)) ?? []
    }
    enum CodingKeys: String, CodingKey { case code, message, episodes }
}

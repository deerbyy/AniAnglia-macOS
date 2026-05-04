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
}

struct NamedItem: Codable, Hashable {
    let id: Int?
    let name: String?
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

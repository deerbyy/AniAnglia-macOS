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

    var thumbnailURL: URL? {
        image.flatMap { URL(string: $0) }
    }

    /// Player URL with schemeless URLs normalized, but without changing http(s)
    /// because some third-party players reject rewritten schemes.
    var resolvedPlayerURL: URL? {
        guard let raw = playerUrl ?? url, !raw.isEmpty else { return nil }
        var s = raw
        if s.hasPrefix("//") { s = "https:" + s }
        return URL(string: s)
    }

    init(id: Int64, title: String?, image: String?, url: String?, playerUrl: String?, hosting: VideoHosting?) {
        self.id = id
        self.title = title
        self.image = image
        self.url = url
        self.playerUrl = playerUrl
        self.hosting = hosting
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: VideoCodingKey.self)
        id = c.decodeInt64("id") ?? c.decodeInt64("video_id") ?? 0
        title = c.decodeString("title") ?? c.decodeString("name")
        image = c.decodeString("image") ?? c.decodeString("image_url") ?? c.decodeString("thumbnail") ?? c.decodeString("thumbnail_url")
        url = c.decodeString("url")
        playerUrl = c.decodeString("player_url") ?? c.decodeString("playerUrl") ?? c.decodeString("iframe_url")
        hosting = try? c.decodeIfPresent(VideoHosting.self, forKey: "hosting")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: VideoCodingKey.self)
        try c.encode(id, forKey: "id")
        try c.encodeIfPresent(title, forKey: "title")
        try c.encodeIfPresent(image, forKey: "image_url")
        try c.encodeIfPresent(url, forKey: "url")
        try c.encodeIfPresent(playerUrl, forKey: "player_url")
        try c.encodeIfPresent(hosting, forKey: "hosting")
    }
}

struct VideoHosting: Codable, Hashable {
    let id: Int?
    let name: String?
    let iconURLString: String?

    var iconURL: URL? { iconURLString.flatMap { URL(string: $0) } }

    init(id: Int?, name: String?, iconURLString: String? = nil) {
        self.id = id
        self.name = name
        self.iconURLString = iconURLString
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: VideoCodingKey.self)
        id = c.decodeInt("id") ?? c.decodeInt("hosting_id")
        name = c.decodeString("name") ?? c.decodeString("title")
        iconURLString = c.decodeString("icon_url") ?? c.decodeString("icon")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: VideoCodingKey.self)
        try c.encodeIfPresent(id, forKey: "id")
        try c.encodeIfPresent(name, forKey: "name")
        try c.encodeIfPresent(iconURLString, forKey: "icon_url")
    }
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

struct VideoCodingKey: CodingKey, ExpressibleByStringLiteral {
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

extension KeyedEncodingContainer where Key == VideoCodingKey {
    mutating func encode<T: Encodable>(_ value: T, forKey key: String) throws {
        try encode(value, forKey: VideoCodingKey(key))
    }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: String) throws {
        try encodeIfPresent(value, forKey: VideoCodingKey(key))
    }
}

extension KeyedDecodingContainer where Key == VideoCodingKey {
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        try decodeIfPresent(type, forKey: VideoCodingKey(key))
    }

    func decodeString(_ key: String) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: VideoCodingKey(key)), !value.isEmpty {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: VideoCodingKey(key)) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: VideoCodingKey(key)) {
            return String(value)
        }
        return nil
    }

    func decodeInt(_ key: String) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: VideoCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int64.self, forKey: VideoCodingKey(key)) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: VideoCodingKey(key)) {
            return Int(value)
        }
        return nil
    }

    func decodeInt64(_ key: String) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: VideoCodingKey(key)) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: VideoCodingKey(key)) {
            return Int64(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: VideoCodingKey(key)) {
            return Int64(value)
        }
        return nil
    }
}

import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: Int64
    let login: String?
    let avatar: String?
    let status: String?
    let lastActivityTime: Int64?
    let registerDate: Int64?
    let watchedReleasesCount: Int?
    let plannedReleasesCount: Int?
    let watchingReleasesCount: Int?
    let abandonedReleasesCount: Int?
    let holdOnReleasesCount: Int?

    var avatarURL: URL? {
        avatar.flatMap { URL(string: $0) }
    }
}

struct ProfileResponse: Codable, CodedResponse {
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

struct SignInResponse: Codable, CodedResponse {
    let code: Int
    let message: String?
    let profileToken: ProfileToken?
    let profile: Profile?

    enum CodingKeys: String, CodingKey {
        case code, message, profile
        case profileToken = "profileToken"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(Int.self, forKey: .code)) ?? 0
        self.message = try? c.decode(String.self, forKey: .message)
        self.profileToken = try? c.decode(ProfileToken.self, forKey: .profileToken)
        self.profile = try? c.decode(Profile.self, forKey: .profile)
    }
}

struct ProfileToken: Codable, Hashable {
    let token: String?
    let sign: String?
}

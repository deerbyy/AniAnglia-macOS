import Foundation

protocol AnixartAPIClient {
    func signIn(login: String, password: String) async throws -> AuthSession
    func interesting() async throws -> [ReleaseSummary]
    func watching(page: Int) async throws -> PagedReleases
    func random() async throws -> ReleaseSummary
    func genres() async throws -> [Genre]
    func search(query: String, filters: SearchFilters, page: Int) async throws -> PagedReleases
    func release(id: Int) async throws -> ReleaseDetail
    func episodes(releaseID: Int) async throws -> EpisodeList
    func episodePlayer(releaseID: Int, sourceID: Int, episodeID: Int) async throws -> EpisodePlayer
    func videos(releaseID: Int) async throws -> [VideoBlock]
    func comments(releaseID: Int, page: Int) async throws -> PagedComments
    func favorites(page: Int) async throws -> PagedReleases
    func addFavorite(releaseID: Int, category: FavoriteCategory) async throws
    func deleteFavorite(releaseID: Int) async throws
    func editWatchStatus(releaseID: Int, status: WatchListStatus) async throws
    func profile(profileID: Int) async throws -> Profile
}

enum AnixartAPIError: LocalizedError, Equatable {
    case invalidURL(String)
    case transportStatus(Int)
    case api(code: Int, message: String?)
    case missingAuthSession
    case invalidAuthResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            "Некорректный URL: \(path)"
        case .transportStatus(let status):
            "Сервер вернул HTTP \(status)"
        case .api(let code, let message):
            message ?? "Anixart API вернул код \(code)"
        case .missingAuthSession:
            "Для действия нужен вход в профиль."
        case .invalidAuthResponse:
            "Сервер не вернул токен профиля."
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

final class AnixartAPI: AnixartAPIClient {
    static let userAgent = "AnixartApp/9.0 beta-11-25052914 (Android 11; SDK 30; arm64-v8a)"

    let baseURL: URL
    private let urlSession: URLSession
    private let authSessionProvider: @Sendable () -> AuthSession?
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://api.anixart.tv")!,
        urlSession: URLSession = .shared,
        authSessionProvider: @escaping @Sendable () -> AuthSession? = { nil }
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.authSessionProvider = authSessionProvider
        decoder = JSONDecoder()
    }

    func signIn(login: String, password: String) async throws -> AuthSession {
        let request = try makeRequest(
            path: "auth/signIn",
            method: .post,
            form: [
                "login": login,
                "password": password
            ],
            includeAuth: false
        )
        let response: SignInResponse = try await perform(request)
        guard let session = response.session else {
            throw AnixartAPIError.invalidAuthResponse
        }
        return session
    }

    func interesting() async throws -> [ReleaseSummary] {
        let request = try makeRequest(path: "discover/interesting")
        let response: ReleaseListResponse = try await perform(request)
        return response.releases
    }

    func watching(page: Int) async throws -> PagedReleases {
        let request = try makeRequest(path: "discover/watching/\(page)")
        return try await perform(request)
    }

    func random() async throws -> ReleaseSummary {
        let request = try makeRequest(path: "release/random")
        let response: ReleaseEnvelope = try await perform(request)
        return response.release.summary
    }

    func genres() async throws -> [Genre] {
        let request = try makeRequest(path: "filter/0")
        let response: FilterResponse = try await perform(request)
        return response.genres
    }

    func search(query: String, filters: SearchFilters, page: Int) async throws -> PagedReleases {
        var form = [
            "query": query,
            "searchBy": "0"
        ]
        if let genreId = filters.genreId {
            form["genres"] = "\(genreId)"
        }
        if let year = filters.year {
            form["year"] = "\(year)"
        }
        if let type = filters.type {
            form["type"] = "\(type)"
        }
        let request = try makeRequest(
            path: "search/releases/\(page)",
            method: .post,
            form: form
        )
        return try await perform(request)
    }

    func release(id: Int) async throws -> ReleaseDetail {
        let request = try makeRequest(path: "release/\(id)")
        let response: ReleaseEnvelope = try await perform(request)
        return response.release
    }

    func episodes(releaseID: Int) async throws -> EpisodeList {
        let request = try makeRequest(path: "episode/\(releaseID)")
        return try await perform(request)
    }

    func episodePlayer(releaseID: Int, sourceID: Int, episodeID: Int) async throws -> EpisodePlayer {
        let request = try makeRequest(path: "episode/\(releaseID)/\(sourceID)/\(episodeID)")
        let response: EpisodePlayerResponse = try await perform(request)
        return response.episode
    }

    func videos(releaseID: Int) async throws -> [VideoBlock] {
        let request = try makeRequest(path: "video/release/\(releaseID)")
        let response: VideoReleaseResponse = try await perform(request)
        return response.blocks
    }

    func comments(releaseID: Int, page: Int) async throws -> PagedComments {
        let request = try makeRequest(path: "release/comment/all/\(releaseID)/\(page)")
        return try await perform(request)
    }

    func favorites(page: Int) async throws -> PagedReleases {
        guard authSessionProvider() != nil else {
            throw AnixartAPIError.missingAuthSession
        }
        let request = try makeRequest(path: "favorite/all/\(page)", includeAuth: true)
        return try await perform(request)
    }

    func addFavorite(releaseID: Int, category: FavoriteCategory) async throws {
        guard authSessionProvider() != nil else {
            throw AnixartAPIError.missingAuthSession
        }
        let request = try makeRequest(
            path: "favorite/add/\(releaseID)",
            method: .post,
            form: ["category": "\(category.rawValue)"],
            includeAuth: true
        )
        let _: EmptyAPIResponse = try await perform(request)
    }

    func deleteFavorite(releaseID: Int) async throws {
        guard authSessionProvider() != nil else {
            throw AnixartAPIError.missingAuthSession
        }
        let request = try makeRequest(path: "favorite/delete/\(releaseID)", method: .post, includeAuth: true)
        let _: EmptyAPIResponse = try await perform(request)
    }

    func editWatchStatus(releaseID: Int, status: WatchListStatus) async throws {
        guard authSessionProvider() != nil else {
            throw AnixartAPIError.missingAuthSession
        }
        let request = try makeRequest(path: "profile/list/edit/\(releaseID)/\(status.rawValue)", method: .post, includeAuth: true)
        let _: EmptyAPIResponse = try await perform(request)
    }

    func profile(profileID: Int) async throws -> Profile {
        let request = try makeRequest(path: "profile/\(profileID)")
        let response: ProfileResponse = try await perform(request)
        return response.profile
    }

    func makeRequest(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        form: [String: String]? = nil,
        includeAuth: Bool = true
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        components?.path = "/" + normalizedPath
        var queryItems = query
        if includeAuth, let session = authSessionProvider() {
            queryItems.append(URLQueryItem(name: "token", value: session.token))
            queryItems.append(URLQueryItem(name: "profile_id", value: "\(session.profileId)"))
        }
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw AnixartAPIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let form {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = formURLEncoded(form).data(using: .utf8)
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await urlSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw AnixartAPIError.transportStatus(httpResponse.statusCode)
        }

        let status = try decoder.decode(APIStatus.self, from: data)
        guard status.code == 0 else {
            throw AnixartAPIError.api(code: status.code, message: status.message)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func formURLEncoded(_ fields: [String: String]) -> String {
        var components = URLComponents()
        components.queryItems = fields
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.percentEncodedQuery ?? ""
    }
}

private struct APIStatus: Decodable {
    let code: Int
    let message: String?
    let errorMessage: String?

    var resolvedMessage: String? {
        message ?? errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = container.decodeFlexibleIntIfPresent(forKey: .code) ?? -1
        message = container.decodeFlexibleStringIfPresent(forKey: .message)
        errorMessage = container.decodeFlexibleStringIfPresent(forKey: .errorMessage)
    }

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case errorMessage = "error_message"
    }
}

private struct EmptyAPIResponse: Decodable { }

private struct ReleaseListResponse: Decodable {
    let releases: [ReleaseSummary]
}

private struct ReleaseEnvelope: Decodable {
    let release: ReleaseDetail
}

private struct EpisodePlayerResponse: Decodable {
    let episode: EpisodePlayer
}

private struct VideoReleaseResponse: Decodable {
    let blocks: [VideoBlock]
}

private struct ProfileResponse: Decodable {
    let profile: Profile
}

private struct FilterResponse: Decodable {
    let genres: [Genre]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genres = (try? container.decodeIfPresent([Genre].self, forKey: .genres)) ??
            (try? container.decodeIfPresent([Genre].self, forKey: .filters)) ??
            (try? container.decodeIfPresent([Genre].self, forKey: .values)) ??
            []
    }

    enum CodingKeys: String, CodingKey {
        case genres
        case filters
        case values
    }
}

private struct SignInResponse: Decodable {
    let session: AuthSession?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let profile = try container.decodeIfPresent(Profile.self, forKey: .profile)
        let token = container.decodeFlexibleStringIfPresent(forKey: .profileToken)
            ?? container.decodeFlexibleStringIfPresent(forKey: .token)
            ?? container.decodeFlexibleStringIfPresent(forKey: .authToken)
        let profileId = container.decodeFlexibleIntIfPresent(forKey: .profileId)
            ?? profile?.id
        if let token, let profileId {
            session = AuthSession(token: token, profileId: profileId, profile: profile)
        } else {
            session = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case profile
        case profileToken = "profile_token"
        case token
        case authToken = "auth_token"
        case profileId = "profile_id"
    }
}

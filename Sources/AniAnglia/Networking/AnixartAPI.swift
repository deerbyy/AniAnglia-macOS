import Foundation

enum APIError: Error, LocalizedError {
    case http(Int)
    case server(code: Int, message: String?)
    case decoding(Error)
    case transport(Error)
    case empty

    var errorDescription: String? {
        switch self {
        case .http(let code): return "HTTP \(code)"
        case .server(let code, let msg): return msg ?? "Ошибка API (code=\(code))"
        case .decoding(let err): return "Не удалось распарсить ответ: \(err.localizedDescription)"
        case .transport(let err): return err.localizedDescription
        case .empty: return "Пустой ответ"
        }
    }
}

@MainActor
final class AnixartAPI {
    static let baseURL = URL(string: "https://api.anixart.tv")!
    static let userAgent = "AnixartApp/9.0 beta-11-25052914 (Android 11; SDK 30; arm64-v8a; samsung; ru_RU)"

    private let session: URLSession
    private let decoder: JSONDecoder
    let auth: AuthStore

    init(auth: AuthStore) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.httpAdditionalHeaders = [
            "User-Agent": Self.userAgent,
            "Accept": "application/json"
        ]
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
        self.auth = auth
    }

    // MARK: - Generic request
    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type = T.self) async throws -> T {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items = query
        if let token = auth.token, let pid = auth.profileId {
            items.append(URLQueryItem(name: "token", value: token))
            items.append(URLQueryItem(name: "profile_id", value: String(pid)))
        }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw APIError.empty }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await perform(req)
    }

    func post<T: Decodable>(_ path: String, form: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let token = auth.token, let pid = auth.profileId {
            items.append(URLQueryItem(name: "token", value: token))
            items.append(URLQueryItem(name: "profile_id", value: String(pid)))
        }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw APIError.empty }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = form.map { (k, v) in
            "\(urlEncode(k))=\(urlEncode(v))"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        return try await perform(req)
    }

    /// POST a JSON-encoded payload (for /filter/{page}, etc).
    func postJSON<T: Decodable>(_ path: String, body: [String: Any], as type: T.Type = T.self) async throws -> T {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let token = auth.token, let pid = auth.profileId {
            items.append(URLQueryItem(name: "token", value: token))
            items.append(URLQueryItem(name: "profile_id", value: String(pid)))
        }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw APIError.empty }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(req)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.empty }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        if data.isEmpty { throw APIError.empty }
        do {
            let envelope = try decoder.decode(T.self, from: data)
            // If T is APIEnvelope-like and reports non-zero code, surface it
            if let coded = envelope as? CodedResponse, coded.code != 0 {
                throw APIError.server(code: coded.code, message: coded.message)
            }
            return envelope
        } catch let APIError.server(code, message) {
            throw APIError.server(code: code, message: message)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

protocol CodedResponse {
    var code: Int { get }
    var message: String? { get }
}

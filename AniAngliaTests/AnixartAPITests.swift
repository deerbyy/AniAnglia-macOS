import Foundation
@testable import AniAngliaMacOS
import XCTest

final class AnixartAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testSignInUsesRequiredHeadersAndFormEncoding() async throws {
        let api = makeAPI()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), AnixartAPI.userAgent)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
            XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "login=user%40mail.com&password=p%40ss")
            return Self.jsonResponse(request: request, json: """
            {"code":0,"profile_token":"token-1","profile_id":42,"profile":{"id":42,"login":"user"}}
            """)
        }

        let session = try await api.signIn(login: "user@mail.com", password: "p@ss")
        XCTAssertEqual(session.token, "token-1")
        XCTAssertEqual(session.profileId, 42)
    }

    func testAuthenticatedRequestInjectsTokenAndProfileID() async throws {
        let api = makeAPI(session: AuthSession(token: "abc", profileId: 7, profile: nil))
        MockURLProtocol.handler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/favorite/all/0")
            let items = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(items["token"] ?? nil, "abc")
            XCTAssertEqual(items["profile_id"] ?? nil, "7")
            return Self.jsonResponse(request: request, json: """
            {"code":0,"releases":[],"total_count":0,"total_page_count":1}
            """)
        }

        let page = try await api.favorites(page: 0)
        XCTAssertTrue(page.releases.isEmpty)
    }

    func testAPICodeErrorIsThrown() async throws {
        let api = makeAPI()
        MockURLProtocol.handler = { request in
            Self.jsonResponse(request: request, json: #"{"code":13,"message":"forbidden"}"#)
        }

        do {
            _ = try await api.interesting()
            XCTFail("Expected API error")
        } catch let error as AnixartAPIError {
            XCTAssertEqual(error, .api(code: 13, message: "forbidden"))
        }
    }

    func testReleaseDecodingToleratesNamedGenres() async throws {
        let api = makeAPI()
        MockURLProtocol.handler = { request in
            Self.jsonResponse(request: request, json: """
            {
              "code": 0,
              "release": {
                "id": "2",
                "title_ru": "Название",
                "title_original": "Original",
                "genres": [{"id": 1, "name": "драма"}],
                "grade": "8.5",
                "episodes_total": "12",
                "screenshot_image_urls": ["https://example.com/1.jpg"]
              }
            }
            """)
        }

        let release = try await api.release(id: 2)
        XCTAssertEqual(release.id, 2)
        XCTAssertEqual(release.summary.genres, ["драма"])
        XCTAssertEqual(release.summary.grade, 8.5)
        XCTAssertEqual(release.screenshotImageUrls.count, 1)
    }

    private func makeAPI(session: AuthSession? = nil) -> AnixartAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return AnixartAPI(
            baseURL: URL(string: "https://api.test")!,
            urlSession: URLSession(configuration: configuration),
            authSessionProvider: { session }
        )
    }

    private static func jsonResponse(request: URLRequest, json: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            Data(json.utf8)
        )
    }
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}

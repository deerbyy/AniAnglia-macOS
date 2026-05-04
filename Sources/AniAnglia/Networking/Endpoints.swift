import Foundation

extension AnixartAPI {
    // MARK: - Discover
    func discoverInteresting() async throws -> [Release] {
        let resp: ReleasesResponse = try await get("discover")
        return resp.releases
    }

    func discoverWatching(page: Int = 0) async throws -> ReleasesResponse {
        try await get("filter/watching/\(page)")
    }

    // MARK: - Release
    func release(id: Int64) async throws -> Release {
        let resp: ReleaseResponse = try await get("release/\(id)")
        guard let release = resp.release else { throw APIError.server(code: resp.code, message: "Релиз не найден") }
        return release
    }

    func randomRelease() async throws -> Release {
        let resp: ReleaseResponse = try await get("release/random")
        guard let release = resp.release else { throw APIError.empty }
        return release
    }

    // MARK: - Search
    func searchReleases(query: String, page: Int = 0) async throws -> ReleasesResponse {
        try await post("search/releases/\(page)", form: [
            "query": query,
            "searchBy": "0"
        ])
    }

    // MARK: - Videos
    func videoBlocks(releaseId: Int64) async throws -> VideoBlocksResponse {
        try await get("video/release/\(releaseId)")
    }

    // MARK: - Bookmarks
    func bookmarks(category: Int, page: Int = 0) async throws -> ReleasesResponse {
        try await get("favorite/all/\(page)", query: [URLQueryItem(name: "category", value: String(category))])
    }

    // MARK: - Profile
    func profile(id: Int64) async throws -> Profile {
        let resp: ProfileResponse = try await get("profile/\(id)")
        guard let profile = resp.profile else { throw APIError.empty }
        return profile
    }

    // MARK: - Auth
    func signIn(login: String, password: String) async throws -> SignInResponse {
        try await post("auth/signIn", form: [
            "login": login,
            "password": password
        ])
    }
}

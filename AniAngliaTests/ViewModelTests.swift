import Foundation
@testable import AniAngliaMacOS
import XCTest

@MainActor
final class ViewModelTests: XCTestCase {
    func testSearchDebounceLoadsFirstPage() async throws {
        let api = StubAPI()
        let viewModel = SearchViewModel()

        viewModel.query = "steel"
        viewModel.scheduleSearch(api: api)
        try await Task.sleep(nanoseconds: 450_000_000)

        XCTAssertEqual(api.lastSearchQuery, "steel")
        XCTAssertEqual(viewModel.releases.map(\.id), [10])
        XCTAssertEqual(viewModel.totalPageCount, 2)
    }

    func testBookmarksLoadMoreAppendsPage() async {
        let api = StubAPI()
        let viewModel = BookmarksViewModel()

        await viewModel.load(api: api)
        await viewModel.loadMore(api: api)

        XCTAssertEqual(viewModel.releases.map(\.id), [20, 21])
    }

    func testReleaseDetailSetsPlayerSession() async {
        let api = StubAPI()
        let viewModel = ReleaseDetailViewModel()

        await viewModel.load(releaseID: 2, api: api)
        await viewModel.openEpisode(Episode.previewList[0], source: EpisodeSource.previewList[0], api: api)

        XCTAssertEqual(viewModel.playerSession?.url.absoluteString, "https://example.com/embed")
    }
}

final class StubAPI: AnixartAPIClient {
    var lastSearchQuery: String?

    func signIn(login: String, password: String) async throws -> AuthSession {
        AuthSession(token: "stub", profileId: 1, profile: .preview)
    }

    func interesting() async throws -> [ReleaseSummary] {
        ReleaseSummary.previewList
    }

    func watching(page: Int) async throws -> PagedReleases {
        PagedReleases(releases: ReleaseSummary.previewList, totalCount: 3, totalPageCount: 1)
    }

    func random() async throws -> ReleaseSummary {
        ReleaseSummary.preview
    }

    func genres() async throws -> [Genre] {
        Genre.previewList
    }

    func search(query: String, filters: SearchFilters, page: Int) async throws -> PagedReleases {
        lastSearchQuery = query
        return PagedReleases(
            releases: [ReleaseSummary(id: 10, titleRu: "Steel", titleOriginal: nil, year: 2024, genres: [], image: nil, status: nil, episodesTotal: nil, episodesReleased: nil, grade: nil, favoriteCategory: nil, watchStatus: nil)],
            totalCount: 2,
            totalPageCount: 2
        )
    }

    func release(id: Int) async throws -> ReleaseDetail {
        ReleaseDetail.preview(id: id)
    }

    func episodes(releaseID: Int) async throws -> EpisodeList {
        EpisodeList(episodes: Episode.previewList, types: [])
    }

    func episodePlayer(releaseID: Int, sourceID: Int, episodeID: Int) async throws -> EpisodePlayer {
        EpisodePlayer(url: "https://example.com/embed", sources: EpisodeSource.previewList)
    }

    func videos(releaseID: Int) async throws -> [VideoBlock] {
        VideoBlock.previewList
    }

    func comments(releaseID: Int, page: Int) async throws -> PagedComments {
        PagedComments(comments: Comment.previewList, totalCount: 2, totalPageCount: 1)
    }

    func favorites(page: Int) async throws -> PagedReleases {
        let release = ReleaseSummary(id: 20 + page, titleRu: "Bookmark \(page)", titleOriginal: nil, year: nil, genres: [], image: nil, status: nil, episodesTotal: nil, episodesReleased: nil, grade: nil, favoriteCategory: .watching, watchStatus: .watching)
        return PagedReleases(releases: [release], totalCount: 2, totalPageCount: 2)
    }

    func addFavorite(releaseID: Int, category: FavoriteCategory) async throws { }
    func deleteFavorite(releaseID: Int) async throws { }
    func editWatchStatus(releaseID: Int, status: WatchListStatus) async throws { }

    func profile(profileID: Int) async throws -> Profile {
        .preview
    }
}

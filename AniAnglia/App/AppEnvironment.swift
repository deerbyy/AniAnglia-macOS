import SwiftUI

private struct AnixartAPIKey: EnvironmentKey {
    static let defaultValue: AnixartAPIClient = PreviewAnixartAPI()
}

extension EnvironmentValues {
    var anixartAPI: AnixartAPIClient {
        get { self[AnixartAPIKey.self] }
        set { self[AnixartAPIKey.self] = newValue }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Темная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

final class PreviewAnixartAPI: AnixartAPIClient {
    func signIn(login: String, password: String) async throws -> AuthSession {
        AuthSession(token: "preview", profileId: 1, profile: Profile.preview)
    }

    func interesting() async throws -> [ReleaseSummary] { ReleaseSummary.previewList }
    func watching(page: Int) async throws -> PagedReleases { PagedReleases(releases: ReleaseSummary.previewList, totalCount: 3, totalPageCount: 1) }
    func random() async throws -> ReleaseSummary { ReleaseSummary.preview }
    func genres() async throws -> [Genre] { Genre.previewList }
    func search(query: String, filters: SearchFilters, page: Int) async throws -> PagedReleases {
        PagedReleases(releases: ReleaseSummary.previewList.filter { query.isEmpty || $0.displayTitle.localizedCaseInsensitiveContains(query) }, totalCount: 3, totalPageCount: 1)
    }
    func release(id: Int) async throws -> ReleaseDetail { ReleaseDetail.preview(id: id) }
    func episodes(releaseID: Int) async throws -> EpisodeList { EpisodeList(episodes: Episode.previewList, types: []) }
    func episodePlayer(releaseID: Int, sourceID: Int, episodeID: Int) async throws -> EpisodePlayer {
        EpisodePlayer(url: "https://example.com/player", sources: EpisodeSource.previewList)
    }
    func videos(releaseID: Int) async throws -> [VideoBlock] { VideoBlock.previewList }
    func comments(releaseID: Int, page: Int) async throws -> PagedComments { PagedComments(comments: Comment.previewList, totalCount: 2, totalPageCount: 1) }
    func favorites(page: Int) async throws -> PagedReleases { PagedReleases(releases: ReleaseSummary.previewList, totalCount: 3, totalPageCount: 1) }
    func addFavorite(releaseID: Int, category: FavoriteCategory) async throws { }
    func deleteFavorite(releaseID: Int) async throws { }
    func editWatchStatus(releaseID: Int, status: WatchListStatus) async throws { }
    func profile(profileID: Int) async throws -> Profile { Profile.preview }
}

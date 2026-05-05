import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let api: AnixartAPI
    let auth: AuthStore
    let bookmarkSync: BookmarkSyncStore
    @Published var selectedSidebar: SidebarItem = .home

    /// When set, a release should be pushed onto the active navigation stack.
    /// `ContentView` observes this and resets it to `nil` after pushing.
    @Published var pendingRelease: Release?

    /// Pre-select bookmark category (1..5) the next time `BookmarksView` opens.
    @Published var pendingBookmarkCategory: Int?

    init() {
        let auth = AuthStore()
        self.auth = auth
        self.api = AnixartAPI(auth: auth)
        self.bookmarkSync = BookmarkSyncStore()
    }

    /// Switch to a sidebar item, optionally pre-selecting a bookmark category.
    func selectSidebar(_ item: SidebarItem, bookmarkCategory: Int? = nil) {
        if item == .bookmarks, let cat = bookmarkCategory {
            pendingBookmarkCategory = cat
        }
        selectedSidebar = item
    }

    /// Push a release onto the current navigation stack.
    func openRelease(_ release: Release) {
        pendingRelease = release
    }
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case home
    case catalog
    case search
    case bookmarks
    case history
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Главная"
        case .catalog: return "Каталог"
        case .search: return "Поиск"
        case .bookmarks: return "Закладки"
        case .history: return "История"
        case .profile: return "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "sparkles"
        case .catalog: return "square.grid.2x2"
        case .search: return "magnifyingglass"
        case .bookmarks: return "bookmark"
        case .history: return "clock"
        case .profile: return "person.crop.circle"
        }
    }
}

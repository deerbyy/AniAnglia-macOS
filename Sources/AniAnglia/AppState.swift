import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let api: AnixartAPI
    let auth: AuthStore
    @Published var selectedSidebar: SidebarItem? = .home

    /// When set, force-pushes a release into the current navigation stack
    /// (used by the "Random release" toolbar action).
    @Published var pendingRelease: Release?

    init() {
        let auth = AuthStore()
        self.auth = auth
        self.api = AnixartAPI(auth: auth)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case home
    case catalog
    case search
    case bookmarks
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Главная"
        case .catalog: return "Каталог"
        case .search: return "Поиск"
        case .bookmarks: return "Закладки"
        case .profile: return "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "sparkles"
        case .catalog: return "square.grid.2x2"
        case .search: return "magnifyingglass"
        case .bookmarks: return "bookmark"
        case .profile: return "person.crop.circle"
        }
    }
}

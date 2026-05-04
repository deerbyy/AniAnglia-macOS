import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let api: AnixartAPI
    let auth: AuthStore
    @Published var selectedSidebar: SidebarItem? = .home

    init() {
        let auth = AuthStore()
        self.auth = auth
        self.api = AnixartAPI(auth: auth)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case home
    case search
    case bookmarks
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Главная"
        case .search: return "Поиск"
        case .bookmarks: return "Закладки"
        case .profile: return "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "sparkles"
        case .search: return "magnifyingglass"
        case .bookmarks: return "bookmark"
        case .profile: return "person.crop.circle"
        }
    }
}

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case search
    case bookmarks
    case profile
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Главная"
        case .search: "Поиск"
        case .bookmarks: "Закладки"
        case .profile: "Профиль"
        case .settings: "Настройки"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "sparkles"
        case .search: "magnifyingglass"
        case .bookmarks: "bookmark"
        case .profile: "person.crop.circle"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection = .home
    @State private var selectedReleaseID: Int?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
                .onChange(of: selectedSection) { _ in
                    selectedReleaseID = nil
                }
        } detail: {
            Group {
                if let selectedReleaseID {
                    ReleaseDetailView(releaseID: selectedReleaseID)
                } else {
                    sectionView
                }
            }
            .navigationTitle(selectedReleaseID == nil ? selectedSection.title : "Релиз")
        }
    }

    @ViewBuilder
    private var sectionView: some View {
        switch selectedSection {
        case .home:
            HomeView(onSelectRelease: { selectedReleaseID = $0 })
        case .search:
            SearchView(onSelectRelease: { selectedReleaseID = $0 })
        case .bookmarks:
            BookmarksView(onSelectRelease: { selectedReleaseID = $0 })
        case .profile:
            ProfileView(onSelectRelease: { selectedReleaseID = $0 })
        case .settings:
            SettingsView()
        }
    }
}

struct SidebarView: View {
    @Binding var selection: AppSection

    var body: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationTitle("AniAnglia")
    }
}

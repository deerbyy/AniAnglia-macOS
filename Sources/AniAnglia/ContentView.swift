import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $appState.selectedSidebar)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            NavigationStack {
                switch appState.selectedSidebar ?? .home {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .bookmarks:
                    BookmarksView()
                case .profile:
                    ProfileView()
                }
            }
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("AniAnglia") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(Optional(item))
                }
            }
        }
        .listStyle(.sidebar)
    }
}

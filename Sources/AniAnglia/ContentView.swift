import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var navPath = NavigationPath()
    @State private var randomError: String?

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $appState.selectedSidebar)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            NavigationStack(path: $navPath) {
                Group {
                    switch appState.selectedSidebar {
                    case .home:
                        HomeView()
                    case .catalog:
                        CatalogView()
                    case .search:
                        SearchView()
                    case .bookmarks:
                        BookmarksView()
                    case .history:
                        HistoryView()
                    case .profile:
                        ProfileView()
                    }
                }
                .navigationDestination(for: Release.self) { release in
                    ReleaseDetailView(releaseId: release.id, prefetched: release)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await openRandomRelease() }
                        } label: {
                            Label("Случайный релиз", systemImage: "shuffle")
                        }
                        .help("Открыть случайный релиз")
                        .keyboardShortcut("r", modifiers: [.command, .shift])
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.selectedSidebar = .search
                        } label: {
                            Label("Поиск", systemImage: "magnifyingglass")
                        }
                        .help("Поиск")
                        .keyboardShortcut("k", modifiers: .command)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        AccountToolbar(auth: appState.auth)
                    }
                }
            }
        }
        .alert("Не удалось", isPresented: Binding(
            get: { randomError != nil },
            set: { if !$0 { randomError = nil } }
        ), actions: {
            Button("ОК") { randomError = nil }
        }, message: {
            Text(randomError ?? "")
        })
        .onChange(of: appState.selectedSidebar) { _, _ in
            navPath = NavigationPath()
        }
        .onChange(of: appState.pendingRelease) { _, newValue in
            guard let release = newValue else { return }
            navPath.append(release)
            appState.pendingRelease = nil
        }
    }

    private func openRandomRelease() async {
        do {
            let release = try await appState.api.randomRelease()
            navPath.append(release)
        } catch {
            randomError = error.localizedDescription
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
            Label(item.title, systemImage: item.systemImage)
        }
        .listStyle(.sidebar)
        .navigationTitle("AniAnglia")
    }
}

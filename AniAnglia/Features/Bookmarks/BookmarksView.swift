import SwiftUI

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var releases: [ReleaseSummary] = []
    @Published var selectedStatus: WatchListStatus = .watching
    @Published var page = 0
    @Published var totalPageCount = 1
    @Published var isLoading = false
    @Published var errorMessage: String?

    var filteredReleases: [ReleaseSummary] {
        releases.filter { release in
            release.watchStatus == selectedStatus || release.favoriteCategory?.rawValue == selectedStatus.rawValue || release.watchStatus == nil
        }
    }

    var canLoadMore: Bool {
        page + 1 < totalPageCount && !isLoading
    }

    func load(api: AnixartAPIClient, reset: Bool = true) async {
        if reset {
            page = 0
            releases = []
        }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.favorites(page: page)
            releases.append(contentsOf: response.releases)
            totalPageCount = max(response.totalPageCount, 1)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore(api: AnixartAPIClient) async {
        guard canLoadMore else { return }
        page += 1
        await load(api: api, reset: false)
    }
}

struct BookmarksView: View {
    let onSelectRelease: (Int) -> Void

    @Environment(\.anixartAPI) private var api
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = BookmarksViewModel()

    var body: some View {
        Group {
            if !authStore.isAuthenticated {
                LoginRequiredView(title: "Закладки доступны после входа")
            } else {
                VStack(spacing: 0) {
                    Picker("Статус", selection: $viewModel.selectedStatus) {
                        ForEach(WatchListStatus.allCases.filter { $0 != .none }) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if viewModel.filteredReleases.isEmpty && !viewModel.isLoading {
                        EmptyStateView(systemImage: "bookmark", title: "Список пуст", message: "Добавьте релиз в выбранный статус на странице релиза.")
                    } else {
                        List {
                            if let errorMessage = viewModel.errorMessage {
                                ErrorBanner(message: errorMessage)
                                    .listRowSeparator(.hidden)
                            }

                            ForEach(viewModel.filteredReleases) { release in
                                ReleaseRow(release: release) {
                                    onSelectRelease(release.id)
                                }
                            }

                            if viewModel.canLoadMore {
                                Button("Загрузить еще") {
                                    Task { await viewModel.loadMore(api: api) }
                                }
                            }

                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listStyle(.inset)
                    }
                }
                .task(id: authStore.currentSession?.profileId) {
                    await viewModel.load(api: api)
                }
                .toolbar {
                    Button {
                        Task { await viewModel.load(api: api) }
                    } label: {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var filters = SearchFilters.empty
    @Published var genres: [Genre] = []
    @Published var releases: [ReleaseSummary] = []
    @Published var page = 0
    @Published var totalPageCount = 1
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    var canLoadMore: Bool {
        page + 1 < totalPageCount && !isLoading
    }

    func loadGenres(api: AnixartAPIClient) async {
        guard genres.isEmpty else { return }
        do {
            genres = try await api.genres()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleSearch(api: AnixartAPIClient) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.search(api: api, reset: true)
        }
    }

    func search(api: AnixartAPIClient, reset: Bool) async {
        if reset {
            page = 0
            releases = []
            totalPageCount = 1
        }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.search(query: query, filters: filters, page: page)
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
        await search(api: api, reset: false)
    }

    func selectGenre(_ genre: Genre?) {
        filters.genreId = genre?.id
    }
}

struct SearchView: View {
    let onSelectRelease: (Int) -> Void

    @Environment(\.anixartAPI) private var api
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if viewModel.releases.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                EmptyStateView(systemImage: "magnifyingglass", title: "Найдите релиз", message: "Введите название или выберите фильтры по жанру, году и типу.")
            } else {
                List {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(viewModel.releases) { release in
                        ReleaseRow(release: release) {
                            onSelectRelease(release.id)
                        }
                    }

                    if viewModel.canLoadMore {
                        Button {
                            Task { await viewModel.loadMore(api: api) }
                        } label: {
                            Label("Загрузить еще", systemImage: "arrow.down.circle")
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
        .searchable(text: $viewModel.query, prompt: "Название релиза")
        .onChange(of: viewModel.query) { _ in
            viewModel.scheduleSearch(api: api)
        }
        .onChange(of: viewModel.filters) { _ in
            viewModel.scheduleSearch(api: api)
        }
        .task {
            await viewModel.loadGenres(api: api)
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.selectGenre(nil)
                    } label: {
                        Chip("Все жанры", isSelected: viewModel.filters.genreId == nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(viewModel.genres) { genre in
                        Button {
                            viewModel.selectGenre(genre)
                        } label: {
                            Chip(genre.name, isSelected: viewModel.filters.genreId == genre.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("Год", value: Binding(
                    get: { viewModel.filters.year },
                    set: { viewModel.filters.year = $0 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)

                Picker("Тип", selection: Binding(
                    get: { viewModel.filters.type ?? -1 },
                    set: { viewModel.filters.type = $0 < 0 ? nil : $0 }
                )) {
                    Text("Любой").tag(-1)
                    Text("TV").tag(1)
                    Text("Фильм").tag(2)
                    Text("OVA/ONA").tag(3)
                }
                .frame(width: 180)

                Spacer()

                Button {
                    viewModel.query = ""
                    viewModel.filters = .empty
                    viewModel.scheduleSearch(api: api)
                } label: {
                    Label("Сбросить", systemImage: "xmark.circle")
                }
            }
        }
        .padding()
        .background(.bar)
    }
}

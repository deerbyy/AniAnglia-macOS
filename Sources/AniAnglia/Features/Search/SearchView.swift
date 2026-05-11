import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Release] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private var currentTask: Task<Void, Never>?
    private var currentPage = 0
    private var totalPageCount: Int?
    private var lastSearchBy = ReleaseSearchScope.title.rawValue

    var canLoadMore: Bool {
        guard !isLoading, !isLoadingMore, !results.isEmpty else { return false }
        guard let totalPageCount else { return true }
        return currentPage + 1 < totalPageCount
    }

    func searchAfterDelay(api: AnixartAPI, searchBy: ReleaseSearchScope) {
        currentTask?.cancel()
        let q = query
        let scope = searchBy.rawValue
        currentTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            guard let self else { return }
            await self.performSearch(api: api, query: q, searchBy: scope)
        }
    }

    func performSearch(api: AnixartAPI, query: String, searchBy: Int) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            errorMessage = nil
            currentPage = 0
            totalPageCount = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.searchReleases(query: trimmed, page: 0, searchBy: searchBy)
            results = resp.items
            currentPage = 0
            totalPageCount = resp.totalPageCount
            lastSearchBy = searchBy
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(api: AnixartAPI) async {
        guard canLoadMore else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let nextPage = currentPage + 1
            let resp = try await api.searchReleases(query: trimmed, page: nextPage, searchBy: lastSearchBy)
            results.append(contentsOf: resp.items)
            currentPage = nextPage
            totalPageCount = resp.totalPageCount ?? totalPageCount
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum ReleaseSearchScope: Int, CaseIterable, Identifiable, Hashable {
    case title = 0
    case studio = 1
    case director = 2
    case author = 3
    case genre = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .title: return "Название"
        case .studio: return "Студия"
        case .director: return "Режиссёр"
        case .author: return "Автор"
        case .genre: return "Жанр"
        }
    }
}

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = SearchViewModel()
    @FocusState private var searchFieldFocused: Bool
    @State private var searchScope: ReleaseSearchScope = .title

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding()
            content
        }
        .navigationTitle("Поиск")
        .onAppear { searchFieldFocused = true }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Название, студия, автор…", text: $vm.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFieldFocused)
                    .onChange(of: vm.query) { _ in
                        vm.searchAfterDelay(api: appState.api, searchBy: searchScope)
                    }
                    .onSubmit {
                        Task { await vm.performSearch(api: appState.api, query: vm.query, searchBy: searchScope.rawValue) }
                    }
                if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
                        vm.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Text("Искать по")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Искать по", selection: $searchScope) {
                    ForEach(ReleaseSearchScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                Spacer()
            }
        }
        .onChange(of: searchScope) { newValue in
            vm.searchAfterDelay(api: appState.api, searchBy: newValue)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.results.isEmpty {
            ProgressView().padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage, vm.results.isEmpty {
            ErrorState(message: error) {
                Task { await vm.performSearch(api: appState.api, query: vm.query, searchBy: searchScope.rawValue) }
            }
        } else if vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Начни вводить название аниме")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.results.isEmpty {
            VStack(spacing: 8) {
                Text("Ничего не найдено")
                    .font(.headline)
                Text("Попробуй другой запрос")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(vm.results) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()

                if vm.canLoadMore {
                    Button {
                        Task { await vm.loadMore(api: appState.api) }
                    } label: {
                        if vm.isLoadingMore {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Показать ещё", systemImage: "chevron.down")
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

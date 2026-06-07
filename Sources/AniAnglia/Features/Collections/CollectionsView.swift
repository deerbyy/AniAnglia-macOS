import SwiftUI

enum CollectionsMode: String, CaseIterable, Identifiable {
    case popular
    case week
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: return "Популярные"
        case .week: return "За неделю"
        case .favorites: return "Избранные"
        }
    }
}

@MainActor
final class CollectionsViewModel: ObservableObject {
    @Published var mode: CollectionsMode = .popular
    @Published var sort: CollectionSort = .yearPopular
    @Published var searchQuery = ""
    @Published var collections: [AnixartCollection] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private var page = 0
    private var totalPageCount: Int?
    private var reachedEnd = false

    var canLoadMore: Bool {
        !isLoading && !isLoadingMore && !reachedEnd
    }

    var filteredCollections: [AnixartCollection] {
        collections.filter { $0.matchesLibraryQuery(searchQuery) }
    }

    var hasSearchQuery: Bool {
        !searchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    func load(api: AnixartAPI, reset: Bool = true) async {
        if mode == .favorites, !api.auth.isAuthenticated {
            collections = []
            errorMessage = nil
            reachedEnd = true
            return
        }

        if reset {
            page = 0
            totalPageCount = nil
            reachedEnd = false
            collections = []
            isLoading = true
        } else {
            guard canLoadMore else { return }
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let response = try await loadPage(api: api, page: page)
            let newItems = response.items
            totalPageCount = response.totalPageCount
            collections = deduplicated(reset ? newItems : collections + newItems)
            errorMessage = nil

            if let totalPageCount {
                reachedEnd = page + 1 >= totalPageCount
            } else {
                reachedEnd = newItems.isEmpty
            }
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeMode(_ nextMode: CollectionsMode, api: AnixartAPI) async {
        guard nextMode != mode else { return }
        mode = nextMode
        await load(api: api, reset: true)
    }

    func changeSort(_ nextSort: CollectionSort, api: AnixartAPI) async {
        guard nextSort != sort else { return }
        sort = nextSort
        await load(api: api, reset: true)
    }

    func loadMoreIfNeeded(current collection: AnixartCollection, api: AnixartAPI) async {
        guard collection.id == collections.last?.id else { return }
        await load(api: api, reset: false)
    }

    private func loadPage(api: AnixartAPI, page: Int) async throws -> CollectionsResponse {
        switch mode {
        case .popular:
            return try await api.collections(page: page, scope: 1, sort: sort)
        case .week:
            return try await api.discoverWeekCollections(page: page)
        case .favorites:
            return try await api.favoriteCollections(page: page)
        }
    }

    private func deduplicated(_ input: [AnixartCollection]) -> [AnixartCollection] {
        var seen = Set<Int64>()
        return input.filter { collection in
            seen.insert(collection.id).inserted
        }
    }
}

struct CollectionsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = CollectionsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .navigationTitle("Коллекции")
        .task(id: appState.auth.profileId) {
            await vm.load(api: appState.api, reset: true)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.load(api: appState.api, reset: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Обновить коллекции")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("", selection: Binding(
                    get: { vm.mode },
                    set: { mode in Task { await vm.changeMode(mode, api: appState.api) } }
                )) {
                    ForEach(CollectionsMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if vm.mode == .popular {
                    Picker("Сортировка", selection: Binding(
                        get: { vm.sort },
                        set: { sort in Task { await vm.changeSort(sort, api: appState.api) } }
                    )) {
                        ForEach(CollectionSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220)
                }
            }

            if !vm.collections.isEmpty || vm.hasSearchQuery {
                searchField
            }

            HStack {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !vm.collections.isEmpty {
                    Text("\(vm.filteredCollections.count)/\(vm.collections.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if vm.mode == .favorites, !appState.auth.isAuthenticated {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Нужен вход в аккаунт")
                    .font(.headline)
                Text("Избранные коллекции синхронизируются с аккаунтом Anixart.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.isLoading && vm.collections.isEmpty {
            ProgressView()
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage, vm.collections.isEmpty {
            ErrorState(message: error) {
                Task { await vm.load(api: appState.api, reset: true) }
            }
        } else if vm.collections.isEmpty {
            Text("Коллекций пока нет")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.filteredCollections.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("По этому запросу ничего не найдено")
                    .font(.headline)
                Text("Можно очистить поиск или загрузить ещё страницы.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if vm.canLoadMore {
                    Button {
                        Task { await vm.load(api: appState.api, reset: false) }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isLoadingMore {
                                ProgressView().controlSize(.small)
                            }
                            Text("Загрузить ещё")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoadingMore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                let visibleCollections = vm.filteredCollections
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], alignment: .leading, spacing: 22) {
                    ForEach(visibleCollections) { collection in
                        NavigationLink(value: CollectionRoute(collection)) {
                            CollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            guard !vm.hasSearchQuery else { return }
                            Task { await vm.loadMoreIfNeeded(current: collection, api: appState.api) }
                        }
                    }

                    if vm.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 260, height: 146)
                    } else if vm.canLoadMore {
                        Button {
                            Task { await vm.load(api: appState.api, reset: false) }
                        } label: {
                            Label("Загрузить ещё", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .frame(width: 260, height: 146)
                    }
                }
                .padding()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск по коллекциям", text: $vm.searchQuery)
                .textFieldStyle(.plain)
            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Очистить поиск")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 360, alignment: .leading)
    }

    private var subtitle: String {
        switch vm.mode {
        case .popular:
            return "Публичные подборки сообщества Anixart: \(vm.sort.title.lowercased())."
        case .week:
            return "Самые активные подборки недели."
        case .favorites:
            return "Синхронизировано с аккаунтом Anixart."
        }
    }
}

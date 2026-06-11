import SwiftUI

@MainActor
final class ProfileListViewModel: ObservableObject {
    @Published var releases: [Release] = []
    @Published var sort: ProfileListSort = .dateAddedNewest
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    let route: ProfileListRoute

    private var page = 0
    private var totalPageCount: Int?
    private var reachedEnd = false

    init(route: ProfileListRoute) {
        self.route = route
    }

    var filteredReleases: [Release] {
        releases.filter { $0.matchesLibraryQuery(searchQuery) }
    }

    var hasSearchQuery: Bool {
        !searchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    var canLoadMore: Bool {
        !isLoading && !isLoadingMore && !reachedEnd
    }

    var loadedCountText: String {
        if hasSearchQuery {
            return "\(filteredReleases.count) из \(releases.count)"
        }
        return "\(releases.count)"
    }

    func reload(api: AnixartAPI) async {
        isLoading = true
        errorMessage = nil
        page = 0
        totalPageCount = nil
        reachedEnd = false
        defer { isLoading = false }

        do {
            let response = try await api.profileListReleases(
                profileId: route.profileId,
                category: route.category,
                page: 0,
                sort: sort
            )
            let incoming = response.items.map { $0.withProfileListStatus(route.category.rawValue) }
            releases = deduplicated(incoming)
            totalPageCount = response.totalPageCount
            reachedEnd = isLastPage(currentPage: 0, pageItems: incoming)
            page = 1
        } catch {
            errorMessage = error.localizedDescription
            releases = []
        }
    }

    func loadMore(api: AnixartAPI) async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await api.profileListReleases(
                profileId: route.profileId,
                category: route.category,
                page: page,
                sort: sort
            )
            let incoming = response.items.map { $0.withProfileListStatus(route.category.rawValue) }
            releases = deduplicated(releases + incoming)
            totalPageCount = response.totalPageCount
            reachedEnd = isLastPage(currentPage: page, pageItems: incoming)
            page += 1
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSort(_ nextSort: ProfileListSort, api: AnixartAPI) async {
        guard nextSort != sort else { return }
        sort = nextSort
        await reload(api: api)
    }

    func loadMoreIfNeeded(current release: Release, api: AnixartAPI) async {
        guard release.id == filteredReleases.last?.id else { return }
        await loadMore(api: api)
    }

    private func isLastPage(currentPage: Int, pageItems: [Release]) -> Bool {
        if let totalPageCount {
            return currentPage + 1 >= totalPageCount
        }
        return pageItems.isEmpty
    }

    private func deduplicated(_ input: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return input.filter { release in
            seen.insert(release.id).inserted
        }
    }
}

struct ProfileListView: View {
    let route: ProfileListRoute

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: ProfileListViewModel

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 16)]

    init(route: ProfileListRoute) {
        self.route = route
        _vm = StateObject(wrappedValue: ProfileListViewModel(route: route))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                controls

                if let error = vm.errorMessage, vm.releases.isEmpty {
                    ErrorState(message: error) {
                        Task { await vm.reload(api: appState.api) }
                    }
                } else if vm.releases.isEmpty && vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if vm.releases.isEmpty {
                    ContentUnavailable(
                        systemImage: "bookmark",
                        title: "Список пуст",
                        message: "Категория может быть пустой или скрытой настройками приватности Anixart."
                    )
                } else if vm.filteredReleases.isEmpty {
                    ContentUnavailable(
                        systemImage: "magnifyingglass",
                        title: "Ничего не найдено",
                        message: "Попробуй изменить запрос или догрузить список ниже."
                    )
                    paginationFooter
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(vm.filteredReleases) { release in
                            NavigationLink(value: release) {
                                ReleaseCard(release: release)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await vm.loadMoreIfNeeded(current: release, api: appState.api) }
                            }
                        }
                    }
                    paginationFooter
                }
            }
            .padding(20)
        }
        .navigationTitle(route.category.title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.reload(api: appState.api) }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task(id: "\(route.profileId)-\(route.category.rawValue)") {
            if vm.releases.isEmpty {
                await vm.reload(api: appState.api)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.square")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(route.category.title)
                    .font(.title2.bold())
                Text(profileSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(vm.loadedCountText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            searchField
            Picker("Порядок", selection: Binding(
                get: { vm.sort },
                set: { nextSort in Task { await vm.setSort(nextSort, api: appState.api) } }
            )) {
                ForEach(ProfileListSort.displayOrder) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .disabled(vm.isLoading)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск в списке", text: $vm.searchQuery)
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
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if vm.isLoadingMore {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else if vm.canLoadMore {
            Button {
                Task { await vm.loadMore(api: appState.api) }
            } label: {
                Text("Показать ещё")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    private var profileSubtitle: String {
        if let profileName = route.profileName, !profileName.isEmpty {
            return "Профиль: \(profileName)"
        }
        return "Профиль #\(route.profileId)"
    }
}

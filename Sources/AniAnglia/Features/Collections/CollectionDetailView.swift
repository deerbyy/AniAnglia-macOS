import AppKit
import SwiftUI

enum CollectionReleaseLibraryFilter: Hashable, Identifiable {
    case all
    case favorites
    case inAnyList
    case notInLibrary
    case list(BookmarkCategory)

    var id: String {
        switch self {
        case .all: return "all"
        case .favorites: return "favorites"
        case .inAnyList: return "in-any-list"
        case .notInLibrary: return "not-in-library"
        case .list(let category): return "list-\(category.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .all: return "Все релизы"
        case .favorites: return "Избранное"
        case .inAnyList: return "В списках"
        case .notInLibrary: return "Без списка"
        case .list(let category): return category.title
        }
    }

    static let displayOrder: [CollectionReleaseLibraryFilter] = [
        .all,
        .favorites,
        .inAnyList,
        .notInLibrary
    ] + BookmarkCategory.displayOrder.map(CollectionReleaseLibraryFilter.list)

    @MainActor
    func includes(_ release: Release, syncStore: BookmarkSyncStore) -> Bool {
        switch self {
        case .all:
            return true
        case .favorites:
            return release.isFavorite == true || syncStore.isFavorite(releaseId: release.id)
        case .inAnyList:
            return release.profileListStatus != nil || syncStore.category(for: release.id) != nil
        case .notInLibrary:
            let isFavorite = release.isFavorite == true || syncStore.isFavorite(releaseId: release.id)
            let isListed = release.profileListStatus != nil || syncStore.category(for: release.id) != nil
            return !isFavorite && !isListed
        case .list(let category):
            return release.profileListStatus == category.rawValue || syncStore.category(for: release.id) == category
        }
    }
}

@MainActor
final class CollectionDetailViewModel: ObservableObject {
    @Published var collection: AnixartCollection?
    @Published var releases: [Release] = []
    @Published var info: CollectionInfo?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var isFavorite = false
    @Published var favoritePending = false
    @Published var releaseSearchQuery = ""
    @Published var releaseLibraryFilter: CollectionReleaseLibraryFilter = .all

    private var page = 0
    private var totalPageCount: Int?
    private var reachedEnd = false
    private var loadedCollectionId: Int64?
    private var loadingCollectionId: Int64?

    var canLoadMore: Bool {
        !isLoading && !isLoadingMore && !reachedEnd
    }

    func filteredReleases(syncStore: BookmarkSyncStore) -> [Release] {
        releases
            .filter { $0.matchesLibraryQuery(releaseSearchQuery) }
            .filter { releaseLibraryFilter.includes($0, syncStore: syncStore) }
    }

    var hasReleaseSearchQuery: Bool {
        !releaseSearchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    var isFilteringLibrary: Bool {
        releaseLibraryFilter != .all
    }

    func load(api: AnixartAPI, collectionId: Int64, prefetched: AnixartCollection?, force: Bool = false) async {
        if isLoading && loadingCollectionId == collectionId {
            return
        }
        if !force, loadedCollectionId == collectionId, collection != nil {
            return
        }

        isLoading = true
        loadingCollectionId = collectionId
        page = 0
        reachedEnd = false
        totalPageCount = nil
        errorMessage = nil
        if let prefetched {
            collection = prefetched
            releases = prefetched.releases
            isFavorite = prefetched.isFavorite ?? false
        }
        defer {
            if loadingCollectionId == collectionId {
                loadingCollectionId = nil
            }
            isLoading = false
        }

        do {
            let nextInfo = try await api.collection(id: collectionId)
            info = nextInfo
            collection = nextInfo.collection
            isFavorite = nextInfo.collection.isFavorite ?? false
        } catch is CancellationError {
            return
        } catch {
            if collection == nil {
                errorMessage = error.localizedDescription
            }
        }

        do {
            let releasesResponse = try await api.collectionReleases(collectionId: collectionId, page: 0)
            let pageItems = releasesResponse.items
            releases = deduplicated(pageItems.isEmpty ? releases : pageItems)
            totalPageCount = releasesResponse.totalPageCount
            if let totalPageCount {
                reachedEnd = 1 >= totalPageCount
            } else {
                reachedEnd = pageItems.isEmpty
            }
            page = 1
        } catch is CancellationError {
            return
        } catch {
            if collection == nil {
                errorMessage = error.localizedDescription
            }
        }

        if collection == nil {
            errorMessage = "Не удалось загрузить коллекцию"
        } else {
            loadedCollectionId = collectionId
        }
    }

    func loadMore(api: AnixartAPI, collectionId: Int64) async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await api.collectionReleases(collectionId: collectionId, page: page)
            let pageItems = response.items
            releases = deduplicated(releases + pageItems)
            totalPageCount = response.totalPageCount
            if let totalPageCount {
                reachedEnd = page + 1 >= totalPageCount
            } else {
                reachedEnd = pageItems.isEmpty
            }
            page += 1
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current release: Release, api: AnixartAPI, collectionId: Int64) async {
        guard release.id == releases.last?.id else { return }
        await loadMore(api: api, collectionId: collectionId)
    }

    func setFavorite(api: AnixartAPI, syncStore: BookmarkSyncStore, collection: AnixartCollection, isFavorite: Bool) async {
        favoritePending = true
        defer { favoritePending = false }
        do {
            try await syncStore.setFavoriteCollection(api: api, collection: collection, isFavorite: isFavorite)
            self.isFavorite = isFavorite
            self.collection = collection.withFavorite(isFavorite)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deduplicated(_ input: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return input.filter { release in
            seen.insert(release.id).inserted
        }
    }
}

struct CollectionDetailView: View {
    let collectionId: Int64
    let prefetched: AnixartCollection?

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = CollectionDetailViewModel()
    @State private var pendingReleaseIds: Set<Int64> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let collection = vm.collection ?? prefetched {
                    header(collection)
                    if !vm.releases.isEmpty {
                        releasesSection
                    }
                } else if vm.isLoading {
                    ProgressView().padding(40)
                } else if let error = vm.errorMessage {
                    ErrorState(message: error) {
                        Task { await vm.load(api: appState.api, collectionId: collectionId, prefetched: prefetched, force: true) }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle((vm.collection ?? prefetched)?.title ?? "Коллекция")
        .task(id: collectionId) {
            await vm.load(api: appState.api, collectionId: collectionId, prefetched: prefetched)
        }
        .alert("Не удалось", isPresented: Binding(
            get: { activeErrorMessage != nil },
            set: {
                if !$0 {
                    vm.errorMessage = nil
                    appState.bookmarkSync.errorMessage = nil
                }
            }
        ), actions: {
            Button("OK") {
                vm.errorMessage = nil
                appState.bookmarkSync.errorMessage = nil
            }
        }, message: {
            Text(activeErrorMessage ?? "")
        })
    }

    private var activeErrorMessage: String? {
        if let error = appState.bookmarkSync.errorMessage {
            return error
        }
        if vm.collection != nil {
            return vm.errorMessage
        }
        return nil
    }

    private func header(_ collection: AnixartCollection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: collection.imageURL, contentMode: .fill) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .overlay(Image(systemName: "rectangle.stack").font(.largeTitle).foregroundStyle(.secondary))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                LinearGradient(colors: [.black.opacity(0.58), .clear], startPoint: .bottom, endPoint: .top)
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    Text(collection.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    HStack(spacing: 10) {
                        if let creator = collection.creator {
                            creatorLink(creator)
                        }
                        if let favoriteCount = collection.favoriteCount {
                            Label("\(favoriteCount)", systemImage: "star")
                        }
                        if let commentCount = collection.commentCount {
                            Label("\(commentCount)", systemImage: "text.bubble")
                        }
                        if collection.isPrivate == true {
                            Label("Приватная", systemImage: "lock")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(18)
            }

            HStack(spacing: 10) {
                collectionFavoriteButton(collection)
                shareMenu(for: collection)
                Spacer()
            }

            Text(collection.displayDescription)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let info = vm.info {
                stats(info)
            }

            accountCoverageSection
        }
    }

    @ViewBuilder
    private func creatorLink(_ creator: Profile) -> some View {
        if creator.id > 0 {
            NavigationLink(value: ProfileRoute(creator)) {
                Label(creator.displayName, systemImage: "person.crop.circle")
            }
            .buttonStyle(.plain)
            .help("Открыть профиль автора")
        } else {
            Label(creator.displayName, systemImage: "person.crop.circle")
        }
    }

    private func collectionFavoriteButton(_ collection: AnixartCollection) -> some View {
        Button {
            Task {
                await vm.setFavorite(
                    api: appState.api,
                    syncStore: appState.bookmarkSync,
                    collection: collection,
                    isFavorite: !vm.isFavorite
                )
            }
        } label: {
            Label(vm.isFavorite ? "В избранных" : "В избранное",
                  systemImage: vm.isFavorite ? "star.fill" : "star")
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(vm.isFavorite ? .yellow : .accentColor)
        .disabled(vm.favoritePending || !appState.auth.isAuthenticated)
        .help(appState.auth.isAuthenticated ? "Синхронизировать избранные коллекции Anixart" : "Войди в аккаунт во вкладке «Профиль», чтобы добавлять коллекции")
    }

    private func shareMenu(for collection: AnixartCollection) -> some View {
        Menu {
            Button {
                copyCollectionTitleAndLink(collection)
            } label: {
                Label("Скопировать название и ссылку", systemImage: "doc.on.doc")
            }

            Button {
                copyToPasteboard(String(collection.id))
            } label: {
                Label("Скопировать ID", systemImage: "number")
            }

            Button {
                NSWorkspace.shared.open(collectionWebURL)
            } label: {
                Label("Открыть в браузере", systemImage: "safari")
            }
        } label: {
            Label("Поделиться", systemImage: "square.and.arrow.up")
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func stats(_ info: CollectionInfo) -> some View {
        HStack(spacing: 10) {
            stat("Смотрю", info.watchingCount)
            stat("В планах", info.planCount)
            stat("Просмотрено", info.watchedCount)
            stat("Отложено", info.holdOnCount)
            stat("Брошено", info.droppedCount)
        }
    }

    private func stat(_ title: String, _ value: Int?) -> some View {
        VStack(spacing: 2) {
            Text("\(value ?? 0)")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var accountCoverageSection: some View {
        let coverage = accountCoverage
        return HStack(spacing: 10) {
            stat("В моей библиотеке", coverage.tracked)
            stat("Избранное", coverage.favorites)
            stat("В списках", coverage.listed)
            stat("Не добавлено", coverage.untracked)
            if appState.bookmarkSync.isSyncing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var accountCoverage: (tracked: Int, favorites: Int, listed: Int, untracked: Int) {
        var tracked = 0
        var favorites = 0
        var listed = 0
        var untracked = 0
        for release in vm.releases {
            let isFavorite = release.isFavorite == true || appState.bookmarkSync.isFavorite(releaseId: release.id)
            let isListed = release.profileListStatus != nil || appState.bookmarkSync.category(for: release.id) != nil
            if isFavorite || isListed { tracked += 1 }
            if isFavorite { favorites += 1 }
            if isListed { listed += 1 }
            if !isFavorite && !isListed { untracked += 1 }
        }
        return (tracked, favorites, listed, untracked)
    }

    private var releasesSection: some View {
        let visibleReleases = vm.filteredReleases(syncStore: appState.bookmarkSync)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Релизы")
                    .font(.title3.bold())
                Text("\(visibleReleases.count)/\(vm.releases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            releaseControls

            if visibleReleases.isEmpty {
                ContentUnavailable(
                    systemImage: "magnifyingglass",
                    title: "Ничего не найдено",
                    message: "Попробуй изменить поиск, фильтр библиотеки или догрузить коллекцию ниже."
                )
                paginationFooter
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(visibleReleases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            ReleaseLibraryContextMenu(
                                appState: appState,
                                release: release,
                                pendingReleaseIds: $pendingReleaseIds
                            )
                        }
                        .onAppear {
                            guard !vm.hasReleaseSearchQuery, !vm.isFilteringLibrary else { return }
                            Task { await vm.loadMoreIfNeeded(current: release, api: appState.api, collectionId: collectionId) }
                        }
                    }
                }
                paginationFooter
            }
        }
    }

    private var releaseControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if vm.releases.count > 8 || vm.hasReleaseSearchQuery {
                    collectionReleaseSearchField
                }

                Picker("Фильтр библиотеки", selection: $vm.releaseLibraryFilter) {
                    ForEach(CollectionReleaseLibraryFilter.displayOrder) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 190)
                .disabled(!appState.auth.isAuthenticated)

                Spacer()

                if vm.hasReleaseSearchQuery || vm.isFilteringLibrary {
                    Button("Сбросить") {
                        vm.releaseSearchQuery = ""
                        vm.releaseLibraryFilter = .all
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
    }

    private var collectionReleaseSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск в коллекции", text: $vm.releaseSearchQuery)
                .textFieldStyle(.plain)
            if !vm.releaseSearchQuery.isEmpty {
                Button {
                    vm.releaseSearchQuery = ""
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

    @ViewBuilder
    private var paginationFooter: some View {
        if vm.isLoadingMore {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else if vm.canLoadMore {
            Button {
                Task { await vm.loadMore(api: appState.api, collectionId: collectionId) }
            } label: {
                Label("Загрузить ещё", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    private var collectionWebURL: URL {
        URL(string: "https://anixart.tv/collection/\(collectionId)")!
    }

    private func copyCollectionTitleAndLink(_ collection: AnixartCollection) {
        copyToPasteboard("\(collection.title)\n\(collectionWebURL.absoluteString)")
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

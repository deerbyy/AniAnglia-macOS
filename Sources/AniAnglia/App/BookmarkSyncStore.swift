import Foundation

struct BookmarkLibraryCounts: Equatable {
    let favoriteReleases: Int
    let favoriteCollections: Int
    let lists: [BookmarkCategory: Int]

    var totalListedReleases: Int {
        lists.values.reduce(0, +)
    }

    var totalAccountItems: Int {
        favoriteReleases + favoriteCollections + totalListedReleases
    }

    func count(for section: AccountLibrarySection) -> Int {
        switch section {
        case .favorites:
            return favoriteReleases
        case .favoriteCollections:
            return favoriteCollections
        case .list(let category):
            return lists[category] ?? 0
        }
    }
}

@MainActor
final class BookmarkSyncStore: ObservableObject {
    @Published private(set) var releasesByCategory: [BookmarkCategory: [Release]] = [:]
    @Published private(set) var favoriteReleases: [Release] = []
    @Published private(set) var favoriteCollections: [AnixartCollection] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var currentReleaseSort: ProfileListSort = .dateAddedNewest
    @Published var errorMessage: String?

    private var categorySyncTasks: [BookmarkCategory: Task<Void, Never>] = [:]
    private var favoritesSyncTask: Task<Void, Never>?
    private var favoriteCollectionsSyncTask: Task<Void, Never>?

    var allReleases: [Release] {
        var seen = Set<Int64>()
        let combined = favoriteReleases + BookmarkCategory.displayOrder.flatMap { category in
            releases(for: category)
        }
        return combined.filter { release in
            seen.insert(release.id).inserted
        }
    }

    func releases(for category: BookmarkCategory) -> [Release] {
        releasesByCategory[category] ?? []
    }

    func count(for category: BookmarkCategory) -> Int {
        releases(for: category).count
    }

    var favoritesCount: Int {
        favoriteReleases.count
    }

    var favoriteCollectionsCount: Int {
        favoriteCollections.count
    }

    var libraryCounts: BookmarkLibraryCounts {
        BookmarkLibraryCounts(
            favoriteReleases: favoriteReleases.count,
            favoriteCollections: favoriteCollections.count,
            lists: Dictionary(uniqueKeysWithValues: BookmarkCategory.displayOrder.map { category in
                (category, count(for: category))
            })
        )
    }

    func category(for releaseId: Int64) -> BookmarkCategory? {
        BookmarkCategory.displayOrder.first { category in
            releases(for: category).contains { $0.id == releaseId }
        }
    }

    func isFavorite(releaseId: Int64) -> Bool {
        favoriteReleases.contains { $0.id == releaseId }
    }

    func clear() {
        categorySyncTasks.values.forEach { $0.cancel() }
        categorySyncTasks = [:]
        favoritesSyncTask?.cancel()
        favoritesSyncTask = nil
        favoriteCollectionsSyncTask?.cancel()
        favoriteCollectionsSyncTask = nil
        releasesByCategory = [:]
        favoriteReleases = []
        favoriteCollections = []
        errorMessage = nil
        lastSyncedAt = nil
        isSyncing = false
    }

    func syncAll(api: AnixartAPI, sort: ProfileListSort = .dateAddedNewest, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        let sortChanged = applyReleaseSort(sort)
        if !force, !sortChanged, lastSyncedAt != nil, !releasesByCategory.isEmpty {
            return
        }

        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            var snapshot: [BookmarkCategory: [Release]] = [:]
            favoriteReleases = try await fetchAllFavoritePages(api: api, sort: sort)
            favoriteCollections = try await fetchAllFavoriteCollectionPages(api: api)
            for category in BookmarkCategory.displayOrder {
                snapshot[category] = try await fetchAllPages(api: api, category: category, sort: sort)
            }
            releasesByCategory = snapshot
            lastSyncedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncFavorites(api: AnixartAPI, sort: ProfileListSort = .dateAddedNewest, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        let sortChanged = applyReleaseSort(sort)
        if !force, !sortChanged, !favoriteReleases.isEmpty {
            return
        }

        favoritesSyncTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let releases = try await self.fetchAllFavoritePages(api: api, sort: sort)
                guard !Task.isCancelled else { return }
                self.favoriteReleases = releases
                self.lastSyncedAt = Date()
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.favoritesSyncTask = nil
        }
        favoritesSyncTask = task
        await task.value
    }

    func syncFavoriteCollections(api: AnixartAPI, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        if !force, !favoriteCollections.isEmpty {
            return
        }

        favoriteCollectionsSyncTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let collections = try await self.fetchAllFavoriteCollectionPages(api: api)
                guard !Task.isCancelled else { return }
                self.favoriteCollections = collections
                self.lastSyncedAt = Date()
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.favoriteCollectionsSyncTask = nil
        }
        favoriteCollectionsSyncTask = task
        await task.value
    }

    func syncCategory(api: AnixartAPI, category: BookmarkCategory, sort: ProfileListSort = .dateAddedNewest, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        let sortChanged = applyReleaseSort(sort)
        if !force, !sortChanged, releasesByCategory[category] != nil {
            return
        }

        categorySyncTasks[category]?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let releases = try await self.fetchAllPages(api: api, category: category, sort: sort)
                guard !Task.isCancelled else { return }
                self.releasesByCategory[category] = releases
                self.lastSyncedAt = Date()
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.categorySyncTasks[category] = nil
        }
        categorySyncTasks[category] = task
        await task.value
    }

    func setStatus(api: AnixartAPI, release: Release, category: BookmarkCategory?) async throws {
        let currentCategory = release.profileListStatus.flatMap(BookmarkCategory.init(rawValue:))
        if category == currentCategory {
            return
        }

        if let category {
            try await api.addToList(releaseId: release.id, category: category)
        } else if let currentCategory {
            try await api.removeFromList(releaseId: release.id, category: currentCategory)
        } else {
            try await api.removeFromList(releaseId: release.id)
        }
        applySyncedStatus(release: release, category: category)

        if let category {
            await syncCategory(api: api, category: category, sort: currentReleaseSort, force: true)
        } else if let currentCategory {
            await syncCategory(api: api, category: currentCategory, sort: currentReleaseSort, force: true)
        }
    }

    func setFavorite(api: AnixartAPI, release: Release, isFavorite: Bool) async throws {
        if release.isFavorite == isFavorite {
            return
        }

        if isFavorite {
            try await api.addToFavorites(releaseId: release.id)
        } else {
            try await api.removeFromFavorites(releaseId: release.id)
        }
        applySyncedFavorite(release: release, isFavorite: isFavorite)
        await syncFavorites(api: api, sort: currentReleaseSort, force: true)
    }

    func setFavoriteCollection(api: AnixartAPI, collection: AnixartCollection, isFavorite: Bool) async throws {
        if collection.isFavorite == isFavorite {
            applySyncedFavoriteCollection(collection: collection, isFavorite: isFavorite)
            return
        }

        if isFavorite {
            try await api.addCollectionToFavorites(collectionId: collection.id)
        } else {
            try await api.removeCollectionFromFavorites(collectionId: collection.id)
        }
        applySyncedFavoriteCollection(collection: collection, isFavorite: isFavorite)
        await syncFavoriteCollections(api: api, force: true)
    }

    private func applySyncedStatus(release: Release, category: BookmarkCategory?) {
        let updatedAt = currentTimestamp()
        for existingCategory in BookmarkCategory.allCases {
            releasesByCategory[existingCategory] = releases(for: existingCategory).filter { $0.id != release.id }
        }
        favoriteReleases = favoriteReleases.map { existing in
            existing.id == release.id
                ? existing.withProfileListStatus(category?.rawValue, updatedAt: updatedAt)
                : existing
        }
        if let category {
            let syncedRelease = release.withProfileListStatus(category.rawValue, updatedAt: updatedAt)
            var releases = releases(for: category)
            releases.insert(syncedRelease, at: 0)
            releasesByCategory[category] = sortedListReleases(deduplicated(releases), category: category, sort: currentReleaseSort)
        }
        lastSyncedAt = Date()
    }

    private func applySyncedFavoriteCollection(collection: AnixartCollection, isFavorite: Bool) {
        favoriteCollections = favoriteCollections.filter { $0.id != collection.id }
        if isFavorite {
            favoriteCollections.insert(collection.withFavorite(true), at: 0)
        }
        lastSyncedAt = Date()
    }

    private func applySyncedFavorite(release: Release, isFavorite: Bool) {
        let syncedRelease = release.withFavorite(isFavorite, updatedAt: currentTimestamp())
        favoriteReleases = favoriteReleases.filter { $0.id != release.id }
        if isFavorite {
            favoriteReleases.insert(syncedRelease, at: 0)
        }
        favoriteReleases = sortedFavoriteReleases(deduplicated(favoriteReleases), sort: currentReleaseSort)
        for category in BookmarkCategory.allCases {
            releasesByCategory[category] = releases(for: category).map { existing in
                existing.id == release.id ? existing.withFavorite(isFavorite) : existing
            }
        }
        lastSyncedAt = Date()
    }

    private func fetchAllFavoritePages(api: AnixartAPI, sort: ProfileListSort) async throws -> [Release] {
        var page = 0
        var all: [Release] = []

        while true {
            let response = try await api.favorites(page: page, sort: sort)
            let pageItems = response.items.map { $0.withFavorite(true) }
            all.append(contentsOf: pageItems)

            if let totalPageCount = response.totalPageCount {
                if page + 1 >= totalPageCount { break }
            } else if pageItems.isEmpty {
                break
            }

            page += 1
            if page > 200 { break }
        }

        return sortedFavoriteReleases(deduplicated(all), sort: sort)
    }

    private func fetchAllFavoriteCollectionPages(api: AnixartAPI) async throws -> [AnixartCollection] {
        var page = 0
        var all: [AnixartCollection] = []

        while true {
            let response = try await api.favoriteCollections(page: page)
            let pageItems = response.items.map { $0.withFavorite(true) }
            all.append(contentsOf: pageItems)

            if let totalPageCount = response.totalPageCount {
                if page + 1 >= totalPageCount { break }
            } else if pageItems.isEmpty {
                break
            }

            page += 1
            if page > 200 { break }
        }

        return deduplicatedCollections(all)
    }

    private func fetchAllPages(api: AnixartAPI, category: BookmarkCategory, sort: ProfileListSort) async throws -> [Release] {
        var page = 0
        var all: [Release] = []

        while true {
            let response = try await api.bookmarks(category: category, page: page, sort: sort)
            let pageItems = response.items.map { $0.withProfileListStatus(category.rawValue) }
            all.append(contentsOf: pageItems)

            if let totalPageCount = response.totalPageCount {
                if page + 1 >= totalPageCount { break }
            } else if pageItems.isEmpty {
                break
            }

            page += 1
            if page > 200 { break }
        }

        return sortedListReleases(deduplicated(all), category: category, sort: sort)
    }

    private func deduplicated(_ releases: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return releases.filter { release in
            seen.insert(release.id).inserted
        }
    }

    private func deduplicatedCollections(_ collections: [AnixartCollection]) -> [AnixartCollection] {
        var seen = Set<Int64>()
        return collections.filter { collection in
            seen.insert(collection.id).inserted
        }
    }

    @discardableResult
    private func applyReleaseSort(_ sort: ProfileListSort) -> Bool {
        guard sort != currentReleaseSort else { return false }
        currentReleaseSort = sort
        releasesByCategory = [:]
        favoriteReleases = []
        return true
    }

    private func sortedFavoriteReleases(_ releases: [Release], sort: ProfileListSort) -> [Release] {
        guard sort.isDateAddedSort else { return releases }
        return stableSorted(releases, newestFirst: sort.newestFirst) { release in
            release.favoriteAddedDate
        }
    }

    private func sortedListReleases(_ releases: [Release], category: BookmarkCategory, sort: ProfileListSort) -> [Release] {
        guard sort.isDateAddedSort else { return releases }
        return stableSorted(releases, newestFirst: sort.newestFirst) { release in
            release.listAddedDate(for: category)
        }
    }

    private func stableSorted(_ releases: [Release], newestFirst: Bool, date: (Release) -> Int64?) -> [Release] {
        releases.enumerated().sorted { lhs, rhs in
            let lhsDate = date(lhs.element)
            let rhsDate = date(rhs.element)
            switch (lhsDate, rhsDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return newestFirst ? lhsDate > rhsDate : lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    private func currentTimestamp() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }
}

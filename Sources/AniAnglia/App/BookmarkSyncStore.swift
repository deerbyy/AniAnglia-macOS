import Foundation

@MainActor
final class BookmarkSyncStore: ObservableObject {
    @Published private(set) var releasesByCategory: [BookmarkCategory: [Release]] = [:]
    @Published private(set) var favoriteReleases: [Release] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published var errorMessage: String?

    private var categorySyncTasks: [BookmarkCategory: Task<Void, Never>] = [:]
    private var favoritesSyncTask: Task<Void, Never>?

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

    func clear() {
        categorySyncTasks.values.forEach { $0.cancel() }
        categorySyncTasks = [:]
        favoritesSyncTask?.cancel()
        favoritesSyncTask = nil
        releasesByCategory = [:]
        favoriteReleases = []
        errorMessage = nil
        lastSyncedAt = nil
        isSyncing = false
    }

    func syncAll(api: AnixartAPI, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        if !force, lastSyncedAt != nil, !releasesByCategory.isEmpty {
            return
        }

        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            var snapshot: [BookmarkCategory: [Release]] = [:]
            favoriteReleases = try await fetchAllFavoritePages(api: api)
            for category in BookmarkCategory.displayOrder {
                snapshot[category] = try await fetchAllPages(api: api, category: category)
            }
            releasesByCategory = snapshot
            lastSyncedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncFavorites(api: AnixartAPI, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        if !force, !favoriteReleases.isEmpty {
            return
        }

        favoritesSyncTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let releases = try await self.fetchAllFavoritePages(api: api)
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

    func syncCategory(api: AnixartAPI, category: BookmarkCategory, force: Bool = false) async {
        guard api.auth.isAuthenticated else {
            clear()
            return
        }
        if !force, releasesByCategory[category] != nil {
            return
        }

        categorySyncTasks[category]?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let releases = try await self.fetchAllPages(api: api, category: category)
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
            applySyncedStatus(release: release, category: category)
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
            await syncCategory(api: api, category: category, force: true)
        } else if let currentCategory {
            await syncCategory(api: api, category: currentCategory, force: true)
        }
    }

    func setFavorite(api: AnixartAPI, release: Release, isFavorite: Bool) async throws {
        if release.isFavorite == isFavorite {
            applySyncedFavorite(release: release, isFavorite: isFavorite)
            return
        }

        if isFavorite {
            try await api.addToFavorites(releaseId: release.id)
        } else {
            try await api.removeFromFavorites(releaseId: release.id)
        }
        applySyncedFavorite(release: release, isFavorite: isFavorite)
        await syncFavorites(api: api, force: true)
    }

    private func applySyncedStatus(release: Release, category: BookmarkCategory?) {
        for existingCategory in BookmarkCategory.allCases {
            releasesByCategory[existingCategory] = releases(for: existingCategory).filter { $0.id != release.id }
        }
        if let category {
            let syncedRelease = release.withProfileListStatus(category.rawValue)
            var releases = releases(for: category)
            releases.insert(syncedRelease, at: 0)
            releasesByCategory[category] = deduplicated(releases)
        }
        lastSyncedAt = Date()
    }

    private func applySyncedFavorite(release: Release, isFavorite: Bool) {
        let syncedRelease = release.withFavorite(isFavorite)
        favoriteReleases = favoriteReleases.filter { $0.id != release.id }
        if isFavorite {
            favoriteReleases.insert(syncedRelease, at: 0)
        }
        for category in BookmarkCategory.allCases {
            releasesByCategory[category] = releases(for: category).map { existing in
                existing.id == release.id ? existing.withFavorite(isFavorite) : existing
            }
        }
        lastSyncedAt = Date()
    }

    private func fetchAllFavoritePages(api: AnixartAPI) async throws -> [Release] {
        var page = 0
        var all: [Release] = []

        while true {
            let response = try await api.favorites(page: page)
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

        return deduplicated(all)
    }

    private func fetchAllPages(api: AnixartAPI, category: BookmarkCategory) async throws -> [Release] {
        var page = 0
        var all: [Release] = []

        while true {
            let response = try await api.bookmarks(category: category, page: page)
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

        return deduplicated(all)
    }

    private func deduplicated(_ releases: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return releases.filter { release in
            seen.insert(release.id).inserted
        }
    }
}

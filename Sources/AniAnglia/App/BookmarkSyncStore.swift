import Foundation

@MainActor
final class BookmarkSyncStore: ObservableObject {
    @Published private(set) var releasesByCategory: [BookmarkCategory: [Release]] = [:]
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published var errorMessage: String?

    private var categorySyncTasks: [BookmarkCategory: Task<Void, Never>] = [:]

    var allReleases: [Release] {
        var seen = Set<Int64>()
        return BookmarkCategory.displayOrder.flatMap { category in
            releases(for: category).filter { release in
                seen.insert(release.id).inserted
            }
        }
    }

    func releases(for category: BookmarkCategory) -> [Release] {
        releasesByCategory[category] ?? []
    }

    func count(for category: BookmarkCategory) -> Int {
        releases(for: category).count
    }

    func clear() {
        categorySyncTasks.values.forEach { $0.cancel() }
        categorySyncTasks = [:]
        releasesByCategory = [:]
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
            for category in BookmarkCategory.displayOrder {
                snapshot[category] = try await fetchAllPages(api: api, category: category)
            }
            releasesByCategory = snapshot
            lastSyncedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
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
        try await api.setProfileListStatus(releaseId: release.id, category: category)
        applySyncedStatus(release: release, category: category)

        if let category {
            await syncCategory(api: api, category: category, force: true)
        }
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

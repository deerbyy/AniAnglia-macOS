import SwiftUI

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var section: AccountLibrarySection = .favorites
    @Published var sort: ProfileListSort = .dateAddedNewest
    @Published var searchQuery = ""

    func select(categoryId: Int) {
        guard let next = BookmarkCategory(rawValue: categoryId) else { return }
        section = .list(next)
    }
}

struct BookmarksView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = BookmarksViewModel()

    var body: some View {
        BookmarksContent(
            appState: appState,
            syncStore: appState.bookmarkSync,
            section: $vm.section,
            sort: $vm.sort,
            searchQuery: $vm.searchQuery
        )
        .navigationTitle("Закладки")
        .task(id: appState.auth.profileId) {
            await appState.bookmarkSync.syncAll(api: appState.api, sort: vm.sort)
        }
        .task(id: "\(vm.section.id)-\(vm.sort.rawValue)") {
            switch vm.section {
            case .favorites:
                await appState.bookmarkSync.syncFavorites(api: appState.api, sort: vm.sort)
            case .favoriteCollections:
                await appState.bookmarkSync.syncFavoriteCollections(api: appState.api)
            case .list(let category):
                await appState.bookmarkSync.syncCategory(api: appState.api, category: category, sort: vm.sort)
            }
        }
        .onAppear {
            if let pending = appState.pendingLibrarySection {
                vm.section = pending
                appState.pendingLibrarySection = nil
            } else if let pending = appState.pendingBookmarkCategory {
                vm.select(categoryId: pending)
                appState.pendingBookmarkCategory = nil
            }
        }
        .onChange(of: appState.pendingLibrarySection) { newValue in
            if let pending = newValue {
                vm.section = pending
                appState.pendingLibrarySection = nil
            }
        }
        .onChange(of: appState.pendingBookmarkCategory) { newValue in
            if let pending = newValue {
                vm.select(categoryId: pending)
                appState.pendingBookmarkCategory = nil
            }
        }
    }
}

private struct BookmarksContent: View {
    @ObservedObject var appState: AppState
    @ObservedObject var syncStore: BookmarkSyncStore
    @Binding var section: AccountLibrarySection
    @Binding var sort: ProfileListSort
    @Binding var searchQuery: String
    @State private var pendingReleaseIds: Set<Int64> = []
    @State private var pendingCollectionIds: Set<Int64> = []

    private var sectionPicker: some View {
        Picker("", selection: $section) {
            ForEach(AccountLibrarySection.displayOrder) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortPicker: some View {
        Picker("Порядок", selection: $sort) {
            ForEach(ProfileListSort.displayOrder) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .disabled(section == .favoriteCollections)
        .help("Порядок релизов в закладках Anixart")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск в текущем списке", text: $searchQuery)
                .textFieldStyle(.plain)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var content: some View {
        if !appState.auth.isAuthenticated {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Нужен вход в аккаунт")
                    .font(.headline)
                Text("Закладки доступны только авторизованным пользователям. Войди на вкладке «Профиль».")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if syncStore.isSyncing && sourceReleases.isEmpty && sourceCollections.isEmpty {
            ProgressView().padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = syncStore.errorMessage, sourceReleases.isEmpty && sourceCollections.isEmpty {
            ErrorState(message: error) {
                Task { await reloadCurrentSection(force: true) }
            }
        } else if sourceReleases.isEmpty && sourceCollections.isEmpty {
            Text("Список пуст")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if releases.isEmpty && collections.isEmpty {
            emptySearchState
        } else if section == .favoriteCollections {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], alignment: .leading, spacing: 22) {
                    ForEach(collections) { collection in
                        NavigationLink(value: CollectionRoute(collection)) {
                            CollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            collectionContextMenu(for: collection)
                        }
                    }
                }
                .padding()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(releases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            releaseContextMenu(for: release)
                        }
                    }
                }
                .padding()
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                sectionPicker
                if appState.auth.isAuthenticated {
                    libraryDashboard
                    searchField
                }
                HStack {
                    if let syncedAt = syncStore.lastSyncedAt {
                        Text("Синхронизировано: \(syncedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Синхронизация с аккаунтом Anixart")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    sortPicker
                    Button {
                        Task { await syncStore.syncAll(api: appState.api, sort: sort, force: true) }
                    } label: {
                        Label("Синхронизировать", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .controlSize(.small)
                    .disabled(syncStore.isSyncing || !appState.auth.isAuthenticated)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            content
        }
        .alert("Не удалось", isPresented: Binding(
            get: { syncStore.errorMessage != nil },
            set: { if !$0 { syncStore.errorMessage = nil } }
        ), actions: {
            Button("OK") { syncStore.errorMessage = nil }
        }, message: {
            Text(syncStore.errorMessage ?? "")
        })
    }

    private var libraryDashboard: some View {
        let counts = syncStore.libraryCounts
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
            ForEach(AccountLibrarySection.displayOrder) { item in
                Button {
                    section = item
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: libraryIcon(for: item))
                                .foregroundStyle(section == item ? .white : libraryTint(for: item))
                            Spacer()
                            Text("\(counts.count(for: item))")
                                .font(.headline.monospacedDigit())
                        }
                        Text(item.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(section == item ? .white : .primary)
                    .background(section == item ? Color.accentColor : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Открыть «\(item.title)»")
            }
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Ничего не найдено")
                .font(.headline)
            Text("Попробуй изменить запрос или выбрать другой раздел.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var releases: [Release] {
        sourceReleases.filter { $0.matchesLibraryQuery(searchQuery) }
    }

    private var collections: [AnixartCollection] {
        sourceCollections.filter { $0.matchesLibraryQuery(searchQuery) }
    }

    private var sourceReleases: [Release] {
        switch section {
        case .favorites:
            return syncStore.favoriteReleases
        case .favoriteCollections:
            return []
        case .list(let category):
            return syncStore.releases(for: category)
        }
    }

    private var sourceCollections: [AnixartCollection] {
        switch section {
        case .favoriteCollections:
            return syncStore.favoriteCollections
        case .favorites, .list(_):
            return []
        }
    }

    private func reloadCurrentSection(force: Bool) async {
        switch section {
        case .favorites:
            await syncStore.syncFavorites(api: appState.api, sort: sort, force: force)
        case .favoriteCollections:
            await syncStore.syncFavoriteCollections(api: appState.api, force: force)
        case .list(let category):
            await syncStore.syncCategory(api: appState.api, category: category, sort: sort, force: force)
        }
    }

    private func libraryIcon(for section: AccountLibrarySection) -> String {
        switch section {
        case .favorites:
            return "star.fill"
        case .favoriteCollections:
            return "rectangle.stack.fill"
        case .list(let category):
            switch category {
            case .watching: return "play.circle.fill"
            case .planned: return "calendar.badge.clock"
            case .watched: return "checkmark.circle.fill"
            case .onHold: return "pause.circle.fill"
            case .dropped: return "xmark.circle.fill"
            }
        }
    }

    private func libraryTint(for section: AccountLibrarySection) -> Color {
        switch section {
        case .favorites:
            return .yellow
        case .favoriteCollections:
            return .purple
        case .list(let category):
            return category.color
        }
    }

    @ViewBuilder
    private func releaseContextMenu(for release: Release) -> some View {
        let currentCategory = currentCategory(for: release)
        let isFavorite = isFavoriteRelease(release)
        let isPending = pendingReleaseIds.contains(release.id)

        Menu("Список") {
            ForEach(BookmarkCategory.displayOrder) { category in
                Button {
                    setReleaseStatus(release, category: category)
                } label: {
                    Label(category.title, systemImage: currentCategory == category ? "checkmark" : "bookmark")
                }
                .disabled(isPending || currentCategory == category)
            }

            if currentCategory != nil {
                Divider()
                Button(role: .destructive) {
                    setReleaseStatus(release, category: nil)
                } label: {
                    Label("Убрать из списка", systemImage: "bookmark.slash")
                }
                .disabled(isPending)
            }
        }

        Button(role: isFavorite ? .destructive : nil) {
            setReleaseFavorite(release, isFavorite: !isFavorite)
        } label: {
            Label(isFavorite ? "Убрать из избранного" : "В избранное",
                  systemImage: isFavorite ? "star.slash" : "star")
        }
        .disabled(isPending)
    }

    @ViewBuilder
    private func collectionContextMenu(for collection: AnixartCollection) -> some View {
        let isFavorite = collection.isFavorite == true || syncStore.favoriteCollections.contains { $0.id == collection.id }
        let isPending = pendingCollectionIds.contains(collection.id)

        Button(role: isFavorite ? .destructive : nil) {
            setCollectionFavorite(collection, isFavorite: !isFavorite)
        } label: {
            Label(isFavorite ? "Убрать из избранных коллекций" : "В избранные коллекции",
                  systemImage: isFavorite ? "star.slash" : "star")
        }
        .disabled(isPending)
    }

    private func currentCategory(for release: Release) -> BookmarkCategory? {
        if let rawValue = release.profileListStatus,
           let category = BookmarkCategory(rawValue: rawValue) {
            return category
        }
        if case .list(let category) = section,
           syncStore.releases(for: category).contains(where: { $0.id == release.id }) {
            return category
        }
        return BookmarkCategory.displayOrder.first { category in
            syncStore.releases(for: category).contains { $0.id == release.id }
        }
    }

    private func isFavoriteRelease(_ release: Release) -> Bool {
        release.isFavorite == true
            || section == .favorites
            || syncStore.favoriteReleases.contains { $0.id == release.id }
    }

    private func releaseForMutation(_ release: Release) -> Release {
        release
            .withProfileListStatus(currentCategory(for: release)?.rawValue)
            .withFavorite(isFavoriteRelease(release))
    }

    private func setReleaseStatus(_ release: Release, category: BookmarkCategory?) {
        Task { @MainActor in
            pendingReleaseIds.insert(release.id)
            defer { pendingReleaseIds.remove(release.id) }
            do {
                try await syncStore.setStatus(
                    api: appState.api,
                    release: releaseForMutation(release),
                    category: category
                )
            } catch {
                syncStore.errorMessage = error.localizedDescription
            }
        }
    }

    private func setReleaseFavorite(_ release: Release, isFavorite: Bool) {
        Task { @MainActor in
            pendingReleaseIds.insert(release.id)
            defer { pendingReleaseIds.remove(release.id) }
            do {
                try await syncStore.setFavorite(
                    api: appState.api,
                    release: releaseForMutation(release),
                    isFavorite: isFavorite
                )
            } catch {
                syncStore.errorMessage = error.localizedDescription
            }
        }
    }

    private func setCollectionFavorite(_ collection: AnixartCollection, isFavorite: Bool) {
        Task { @MainActor in
            pendingCollectionIds.insert(collection.id)
            defer { pendingCollectionIds.remove(collection.id) }
            do {
                try await syncStore.setFavoriteCollection(
                    api: appState.api,
                    collection: collection,
                    isFavorite: isFavorite
                )
            } catch {
                syncStore.errorMessage = error.localizedDescription
            }
        }
    }
}

private extension BookmarkCategory {
    var color: Color {
        switch self {
        case .planned: return .yellow
        case .watching: return .indigo
        case .watched: return .green
        case .onHold: return .purple
        case .dropped: return .red
        }
    }
}

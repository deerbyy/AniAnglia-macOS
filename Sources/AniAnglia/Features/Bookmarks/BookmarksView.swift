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
}

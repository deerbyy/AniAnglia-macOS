import SwiftUI

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var section: AccountLibrarySection = .favorites

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
            section: $vm.section
        )
        .navigationTitle("Закладки")
        .task(id: appState.auth.profileId) {
            await appState.bookmarkSync.syncAll(api: appState.api)
        }
        .task(id: vm.section) {
            switch vm.section {
            case .favorites:
                await appState.bookmarkSync.syncFavorites(api: appState.api)
            case .list(let category):
                await appState.bookmarkSync.syncCategory(api: appState.api, category: category)
            }
        }
        .onAppear {
            if let pending = appState.pendingBookmarkCategory {
                vm.select(categoryId: pending)
                appState.pendingBookmarkCategory = nil
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

    private var sectionPicker: some View {
        Picker("", selection: $section) {
            ForEach(AccountLibrarySection.displayOrder) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
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
        } else if syncStore.isSyncing && releases.isEmpty {
            ProgressView().padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = syncStore.errorMessage, releases.isEmpty {
            ErrorState(message: error) {
                Task { await reloadCurrentSection(force: true) }
            }
        } else if releases.isEmpty {
            Text("Список пуст")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Button {
                        Task { await syncStore.syncAll(api: appState.api, force: true) }
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

    private var releases: [Release] {
        switch section {
        case .favorites:
            return syncStore.favoriteReleases
        case .list(let category):
            return syncStore.releases(for: category)
        }
    }

    private func reloadCurrentSection(force: Bool) async {
        switch section {
        case .favorites:
            await syncStore.syncFavorites(api: appState.api, force: force)
        case .list(let category):
            await syncStore.syncCategory(api: appState.api, category: category, force: force)
        }
    }
}

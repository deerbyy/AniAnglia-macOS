import SwiftUI

struct ReleaseLibraryContextMenu: View {
    @ObservedObject var appState: AppState
    let release: Release
    @Binding var pendingReleaseIds: Set<Int64>

    var body: some View {
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

    private func currentCategory(for release: Release) -> BookmarkCategory? {
        if let rawValue = release.profileListStatus,
           let category = BookmarkCategory(rawValue: rawValue) {
            return category
        }
        return appState.bookmarkSync.category(for: release.id)
    }

    private func isFavoriteRelease(_ release: Release) -> Bool {
        release.isFavorite == true || appState.bookmarkSync.isFavorite(releaseId: release.id)
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
                try await appState.bookmarkSync.setStatus(
                    api: appState.api,
                    release: releaseForMutation(release),
                    category: category
                )
            } catch {
                appState.bookmarkSync.errorMessage = error.localizedDescription
            }
        }
    }

    private func setReleaseFavorite(_ release: Release, isFavorite: Bool) {
        Task { @MainActor in
            pendingReleaseIds.insert(release.id)
            defer { pendingReleaseIds.remove(release.id) }
            do {
                try await appState.bookmarkSync.setFavorite(
                    api: appState.api,
                    release: releaseForMutation(release),
                    isFavorite: isFavorite
                )
            } catch {
                appState.bookmarkSync.errorMessage = error.localizedDescription
            }
        }
    }
}

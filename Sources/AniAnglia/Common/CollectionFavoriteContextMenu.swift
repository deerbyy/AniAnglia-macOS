import SwiftUI

struct CollectionFavoriteContextMenu: View {
    @ObservedObject var appState: AppState
    let collection: AnixartCollection
    @Binding var pendingCollectionIds: Set<Int64>

    var body: some View {
        let isFavorite = isFavoriteCollection(collection)
        let isPending = pendingCollectionIds.contains(collection.id)

        Button(role: isFavorite ? .destructive : nil) {
            setCollectionFavorite(collection, isFavorite: !isFavorite)
        } label: {
            Label(isFavorite ? "Убрать из избранных коллекций" : "В избранные коллекции",
                  systemImage: isFavorite ? "star.slash" : "star")
        }
        .disabled(isPending || !appState.auth.isAuthenticated)
    }

    private func isFavoriteCollection(_ collection: AnixartCollection) -> Bool {
        collection.isFavorite == true || appState.bookmarkSync.favoriteCollections.contains { $0.id == collection.id }
    }

    private func setCollectionFavorite(_ collection: AnixartCollection, isFavorite: Bool) {
        Task { @MainActor in
            pendingCollectionIds.insert(collection.id)
            defer { pendingCollectionIds.remove(collection.id) }
            do {
                try await appState.bookmarkSync.setFavoriteCollection(
                    api: appState.api,
                    collection: collection,
                    isFavorite: isFavorite
                )
            } catch {
                appState.bookmarkSync.errorMessage = error.localizedDescription
            }
        }
    }
}

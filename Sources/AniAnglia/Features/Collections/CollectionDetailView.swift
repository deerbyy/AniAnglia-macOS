import SwiftUI

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

    private var page = 0
    private var totalPageCount: Int?
    private var reachedEnd = false

    var canLoadMore: Bool {
        !isLoading && !isLoadingMore && !reachedEnd
    }

    func load(api: AnixartAPI, collectionId: Int64, prefetched: AnixartCollection?) async {
        isLoading = true
        page = 0
        reachedEnd = false
        totalPageCount = nil
        errorMessage = nil
        if let prefetched {
            collection = prefetched
            releases = prefetched.releases
            isFavorite = prefetched.isFavorite ?? false
        }
        defer { isLoading = false }

        async let loadedInfo: CollectionInfo? = {
            do { return try await api.collection(id: collectionId) }
            catch { return nil }
        }()
        async let loadedReleases: ReleasesResponse? = {
            do { return try await api.collectionReleases(collectionId: collectionId, page: 0) }
            catch { return nil }
        }()

        let nextInfo = await loadedInfo
        let releasesResponse = await loadedReleases

        if let nextInfo {
            info = nextInfo
            collection = nextInfo.collection
            isFavorite = nextInfo.collection.isFavorite ?? false
        }
        if let releasesResponse {
            let pageItems = releasesResponse.items
            releases = deduplicated(pageItems.isEmpty ? releases : pageItems)
            totalPageCount = releasesResponse.totalPageCount
            if let totalPageCount {
                reachedEnd = 1 >= totalPageCount
            } else {
                reachedEnd = pageItems.isEmpty
            }
            page = 1
        }
        if collection == nil {
            errorMessage = "Не удалось загрузить коллекцию"
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
        } catch {
            errorMessage = error.localizedDescription
        }
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
                        Task { await vm.load(api: appState.api, collectionId: collectionId, prefetched: prefetched) }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle((vm.collection ?? prefetched)?.title ?? "Коллекция")
        .task {
            await vm.load(api: appState.api, collectionId: collectionId, prefetched: prefetched)
        }
        .alert("Не удалось", isPresented: Binding(
            get: { vm.errorMessage != nil && vm.collection != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        ), actions: {
            Button("OK") { vm.errorMessage = nil }
        }, message: {
            Text(vm.errorMessage ?? "")
        })
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    Text(collection.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    HStack(spacing: 10) {
                        if let creator = collection.creator {
                            Label(creator.displayName, systemImage: "person.crop.circle")
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

            HStack {
                collectionFavoriteButton(collection)
                Spacer()
            }

            Text(collection.displayDescription)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let info = vm.info {
                stats(info)
            }
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

    private var releasesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Релизы").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                ForEach(vm.releases) { release in
                    NavigationLink(value: release) {
                        ReleaseCard(release: release)
                    }
                    .buttonStyle(.plain)
                }

                if vm.canLoadMore {
                    Button {
                        Task { await vm.loadMore(api: appState.api, collectionId: collectionId) }
                    } label: {
                        if vm.isLoadingMore {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Загрузить ещё", systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 160, height: 230)
                }
            }
        }
    }
}

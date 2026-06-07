import SwiftUI

@MainActor
final class ReleaseDetailViewModel: ObservableObject {
    @Published var release: Release?
    @Published var videoBlocks: [VideoBlock] = []
    @Published var relatedCollections: [AnixartCollection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookmarkCategory: Int? = nil // 0 = none, 1..5 = list category
    @Published var bookmarkPending = false
    @Published var bookmarkError: String?
    @Published var isFavorite = false
    @Published var favoritePending = false
    @Published var userVote: Int = 0 // 0 = none, 1..5 stars
    @Published var votePending = false
    @Published var relatedCollectionsSort: CollectionSort = .yearPopular
    @Published var relatedCollectionsSearchQuery = ""
    @Published var isLoadingMoreRelatedCollections = false
    @Published var selectedVideoCategoryId: Int?
    @Published var videoSearchQuery = ""

    private var relatedCollectionsPage = 0
    private var relatedCollectionsTotalPageCount: Int?
    private var relatedCollectionsReachedEnd = false

    var filteredRelatedCollections: [AnixartCollection] {
        relatedCollections.filter { $0.matchesLibraryQuery(relatedCollectionsSearchQuery) }
    }

    var hasRelatedCollectionsSearchQuery: Bool {
        !relatedCollectionsSearchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    var canLoadMoreRelatedCollections: Bool {
        !isLoading && !isLoadingMoreRelatedCollections && !relatedCollectionsReachedEnd
    }

    var filteredVideoBlocks: [VideoBlock] {
        let needle = videoSearchQuery.normalizedLibrarySearchQuery
        return videoBlocks.compactMap { block in
            if let selectedVideoCategoryId, block.category.id != selectedVideoCategoryId {
                return nil
            }
            let categoryMatches = !needle.isEmpty
                && block.category.name.normalizedLibrarySearchQuery.contains(needle)
            let videos = categoryMatches
                ? block.videos
                : block.videos.filter { $0.matchesVideoQuery(videoSearchQuery) }
            guard !videos.isEmpty else { return nil }
            return VideoBlock(category: block.category, videos: videos)
        }
    }

    var totalVideoCount: Int {
        videoBlocks.reduce(0) { $0 + $1.videos.count }
    }

    var filteredVideoCount: Int {
        filteredVideoBlocks.reduce(0) { $0 + $1.videos.count }
    }

    var hasVideoSearchQuery: Bool {
        !videoSearchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    func load(api: AnixartAPI, releaseId: Int64) async {
        isLoading = true
        let loadedRelease: Release? = await {
            do { return try await api.release(id: releaseId) }
            catch { return nil }
        }()
        let loadedBlocks: [VideoBlock] = await {
            do { return try await api.videoBlocks(releaseId: releaseId).blocks }
            catch { return [] }
        }()
        if let loadedRelease {
            release = loadedRelease
            bookmarkCategory = loadedRelease.profileListStatus
            isFavorite = loadedRelease.isFavorite ?? false
            userVote = loadedRelease.yourVote ?? 0
        }
        videoBlocks = loadedBlocks
        await loadRelatedCollections(api: api, releaseId: releaseId, reset: true)
        if release == nil && errorMessage == nil {
            errorMessage = "Не удалось загрузить релиз"
        }
        isLoading = false
    }

    func loadRelatedCollections(api: AnixartAPI, releaseId: Int64, reset: Bool = false) async {
        if reset {
            relatedCollectionsPage = 0
            relatedCollectionsTotalPageCount = nil
            relatedCollectionsReachedEnd = false
            relatedCollections = []
        } else {
            guard canLoadMoreRelatedCollections else { return }
            isLoadingMoreRelatedCollections = true
        }
        defer { isLoadingMoreRelatedCollections = false }

        do {
            let page = relatedCollectionsPage
            let response = try await api.releaseCollections(
                releaseId: releaseId,
                page: page,
                sort: relatedCollectionsSort
            )
            let incoming = response.items
            relatedCollections = deduplicatedCollections(reset ? incoming : relatedCollections + incoming)
            relatedCollectionsTotalPageCount = response.totalPageCount
            if let relatedCollectionsTotalPageCount {
                relatedCollectionsReachedEnd = page + 1 >= relatedCollectionsTotalPageCount
            } else {
                relatedCollectionsReachedEnd = incoming.isEmpty
            }
            relatedCollectionsPage = page + 1
        } catch {
            if !reset {
                bookmarkError = error.localizedDescription
            }
        }
    }

    func changeRelatedCollectionsSort(_ sort: CollectionSort, api: AnixartAPI, releaseId: Int64) async {
        guard sort != relatedCollectionsSort else { return }
        relatedCollectionsSort = sort
        await loadRelatedCollections(api: api, releaseId: releaseId, reset: true)
    }

    func setRating(api: AnixartAPI, releaseId: Int64, stars: Int) async {
        let previous = userVote
        let next = stars == userVote ? 0 : stars
        userVote = next
        votePending = true
        defer { votePending = false }
        do {
            if next == 0 {
                _ = try await api.unrateRelease(releaseId: releaseId)
            } else {
                _ = try await api.rateRelease(releaseId: releaseId, stars: next)
            }
        } catch {
            userVote = previous
            bookmarkError = error.localizedDescription
        }
    }

    func setBookmark(api: AnixartAPI, syncStore: BookmarkSyncStore, release: Release, category: BookmarkCategory?) async {
        bookmarkPending = true
        defer { bookmarkPending = false }
        do {
            try await syncStore.setStatus(api: api, release: release, category: category)
            bookmarkCategory = category?.rawValue
            self.release = release.withProfileListStatus(category?.rawValue)
            bookmarkError = nil
        } catch {
            bookmarkError = error.localizedDescription
        }
    }

    func setFavorite(api: AnixartAPI, syncStore: BookmarkSyncStore, release: Release, isFavorite: Bool) async {
        favoritePending = true
        defer { favoritePending = false }
        do {
            try await syncStore.setFavorite(api: api, release: release, isFavorite: isFavorite)
            self.isFavorite = isFavorite
            self.release = release.withFavorite(isFavorite)
            bookmarkError = nil
        } catch {
            bookmarkError = error.localizedDescription
        }
    }

    private func deduplicatedCollections(_ collections: [AnixartCollection]) -> [AnixartCollection] {
        var seen = Set<Int64>()
        return collections.filter { collection in
            seen.insert(collection.id).inserted
        }
    }
}

struct ReleaseDetailView: View {
    let releaseId: Int64
    let prefetched: Release?

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = ReleaseDetailViewModel()
    @State private var fullscreenScreenshots: [URL]?
    @State private var fullscreenIndex: Int = 0
    @State private var playingVideo: Video?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let release = effectiveRelease {
                    info(for: release)
                    if !vm.videoBlocks.isEmpty {
                        videosSection
                    }
                    if !vm.relatedCollections.isEmpty {
                        relatedCollectionsSection
                    }
                    if !release.screenshots.isEmpty {
                        screenshotsSection(urls: release.screenshots)
                    }
                    description(for: release)
                    Divider().padding(.vertical, 8)
                    CommentsView(releaseId: releaseId)
                } else if vm.isLoading {
                    ProgressView().padding()
                } else if let error = vm.errorMessage {
                    ErrorState(message: error) {
                        Task { await vm.load(api: appState.api, releaseId: releaseId) }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(effectiveRelease?.displayTitle ?? "Релиз")
        .task { await vm.load(api: appState.api, releaseId: releaseId) }
        .sheet(item: $playingVideo) { video in
            VideoPlayerSheet(video: video)
        }
        .sheet(isPresented: Binding(get: { fullscreenScreenshots != nil }, set: { if !$0 { fullscreenScreenshots = nil } })) {
            if let urls = fullscreenScreenshots {
                ScreenshotsViewer(urls: urls, initialIndex: fullscreenIndex) {
                    fullscreenScreenshots = nil
                }
            }
        }
        .alert("Не удалось", isPresented: Binding(
            get: { vm.bookmarkError != nil },
            set: { if !$0 { vm.bookmarkError = nil } }
        ), actions: {
            Button("OK") { vm.bookmarkError = nil }
        }, message: {
            Text(vm.bookmarkError ?? "")
        })
    }

    private var effectiveRelease: Release? {
        vm.release ?? prefetched
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            RemoteImage(url: effectiveRelease?.posterURL, contentMode: .fill) {
                Rectangle().fill(Color.secondary.opacity(0.1))
            }
            .frame(width: 220, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 8)

            VStack(alignment: .leading, spacing: 12) {
                if let release = effectiveRelease {
                    Text(release.displayTitle)
                        .font(.system(size: 28, weight: .bold))
                    if let original = release.titleOriginal, original != release.displayTitle {
                        Text(original)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        if let year = release.year { Tag(text: year) }
                        if let status = release.status?.name { Tag(text: status) }
                        if let category = release.category?.name { Tag(text: category) }
                        if let grade = release.grade {
                            Tag(text: String(format: "★ %.2f", grade), tint: .yellow)
                        }
                    }
                    if let genres = release.genres, !genres.isEmpty {
                        Text(genres)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if appState.auth.isAuthenticated {
                        userRatingRow
                    }
                    actionsRow
                }
                Spacer()
            }
            Spacer()
        }
    }

    private var userRatingRow: some View {
        HStack(spacing: 4) {
            Text(vm.userVote == 0 ? "Оценить:" : "Твоя оценка:")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(1...5, id: \.self) { star in
                Button {
                    Task { await vm.setRating(api: appState.api, releaseId: releaseId, stars: star) }
                } label: {
                    Image(systemName: star <= vm.userVote ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(star <= vm.userVote ? Color.yellow : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(vm.votePending)
            }
            if vm.userVote > 0 {
                Button {
                    Task { await vm.setRating(api: appState.api, releaseId: releaseId, stars: vm.userVote) }
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Убрать свою оценку")
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            NavigationLink {
                EpisodesView(releaseId: releaseId, releaseTitle: effectiveRelease?.displayTitle)
            } label: {
                Label("Смотреть", systemImage: "play.fill")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            bookmarkMenu
            favoriteButton
        }
        .padding(.top, 8)
    }

    private var favoriteButton: some View {
        Button {
            if let release = effectiveRelease {
                Task {
                    await vm.setFavorite(
                        api: appState.api,
                        syncStore: appState.bookmarkSync,
                        release: release,
                        isFavorite: !vm.isFavorite
                    )
                }
            }
        } label: {
            Label(vm.isFavorite ? "В избранном" : "В избранное",
                  systemImage: vm.isFavorite ? "star.fill" : "star")
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(vm.isFavorite ? .yellow : .accentColor)
        .fixedSize()
        .disabled(vm.favoritePending || !appState.auth.isAuthenticated)
        .help(appState.auth.isAuthenticated ? "Синхронизировать избранное Anixart" : "Войди в аккаунт во вкладке «Профиль», чтобы добавлять в избранное")
    }

    private var bookmarkMenu: some View {
        let current = vm.bookmarkCategory
        let currentCategory = current.flatMap(BookmarkCategory.init(rawValue:))
        return Menu {
            ForEach(BookmarkCategory.displayOrder) { category in
                Button {
                    if let release = effectiveRelease {
                        Task { await vm.setBookmark(api: appState.api, syncStore: appState.bookmarkSync, release: release, category: category) }
                    }
                } label: {
                    if current == category.rawValue {
                        Label(category.title, systemImage: "checkmark")
                    } else {
                        Text(category.title)
                    }
                }
            }
            if current != nil {
                Divider()
                Button(role: .destructive) {
                    if let release = effectiveRelease {
                        Task { await vm.setBookmark(api: appState.api, syncStore: appState.bookmarkSync, release: release, category: nil) }
                    }
                } label: {
                    Label("Убрать из списка", systemImage: "bookmark.slash")
                }
            }
        } label: {
            Label(currentCategory?.title ?? "В закладки",
                  systemImage: currentCategory == nil ? "bookmark" : "bookmark.fill")
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(currentCategory?.color ?? .accentColor)
        }
        .fixedSize()
        .disabled(vm.bookmarkPending || !appState.auth.isAuthenticated)
        .help(appState.auth.isAuthenticated ? "Списки отслеживания" : "Войди в аккаунт во вкладке «Профиль», чтобы добавлять в закладки")
    }

    private func info(for release: Release) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Студия", release.studio)
            row("Страна", release.country)
            row("Автор", release.author)
            row("Режиссёр", release.director)
            row("Серий вышло", release.episodesReleased.map { String($0) })
            row("Серий всего", release.episodesTotal.map { String($0) })
        }
        .font(.callout)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Text(label)
                    .frame(width: 120, alignment: .leading)
                    .foregroundStyle(.secondary)
                Text(value)
            }
        }
    }

    private func description(for release: Release) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание").font(.title3.bold())
            Text(release.description ?? "—")
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private var videosSection: some View {
        let visibleBlocks = vm.filteredVideoBlocks
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Видео")
                    .font(.title3.bold())
                Text("\(vm.filteredVideoCount)/\(vm.totalVideoCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            videoControls

            if visibleBlocks.isEmpty {
                Text("По этому запросу видео не найдены.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(visibleBlocks) { block in
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.category.name)
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(block.videos) { video in
                                Button {
                                    playingVideo = video
                                } label: {
                                    VideoThumbnail(video: video)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var videoControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                videoSearchField
                if vm.videoBlocks.count > 1 {
                    Picker("Категория", selection: $vm.selectedVideoCategoryId) {
                        Text("Все категории").tag(Int?.none)
                        ForEach(vm.videoBlocks) { block in
                            Text(block.category.name).tag(Int?.some(block.category.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220)
                }
                Spacer()
            }
        }
    }

    private var videoSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск по видео", text: $vm.videoSearchQuery)
                .textFieldStyle(.plain)
            if !vm.videoSearchQuery.isEmpty {
                Button {
                    vm.videoSearchQuery = ""
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

    private var relatedCollectionsSection: some View {
        let visibleCollections = vm.filteredRelatedCollections
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("В коллекциях")
                    .font(.title3.bold())
                Text("\(visibleCollections.count)/\(vm.relatedCollections.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Сортировка", selection: Binding(
                    get: { vm.relatedCollectionsSort },
                    set: { sort in
                        Task {
                            await vm.changeRelatedCollectionsSort(
                                sort,
                                api: appState.api,
                                releaseId: releaseId
                            )
                        }
                    }
                )) {
                    ForEach(CollectionSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
            }

            if vm.relatedCollections.count > 6 || vm.hasRelatedCollectionsSearchQuery {
                relatedCollectionsSearchField
            }

            if visibleCollections.isEmpty {
                Text("По этому запросу коллекции не найдены.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(visibleCollections) { collection in
                        NavigationLink(value: CollectionRoute(collection)) {
                            CollectionCard(collection: collection, style: .compact)
                        }
                        .buttonStyle(.plain)
                    }

                    if vm.canLoadMoreRelatedCollections {
                        Button {
                            Task {
                                await vm.loadRelatedCollections(
                                    api: appState.api,
                                    releaseId: releaseId
                                )
                            }
                        } label: {
                            VStack(spacing: 8) {
                                if vm.isLoadingMoreRelatedCollections {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "chevron.right.circle")
                                        .font(.title2)
                                }
                                Text("Ещё")
                                    .font(.caption.weight(.medium))
                            }
                            .frame(width: 116, height: 124)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isLoadingMoreRelatedCollections)
                    }
                }
            }
        }
    }

    private var relatedCollectionsSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск по коллекциям", text: $vm.relatedCollectionsSearchQuery)
                .textFieldStyle(.plain)
            if !vm.relatedCollectionsSearchQuery.isEmpty {
                Button {
                    vm.relatedCollectionsSearchQuery = ""
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

    private func screenshotsSection(urls: [URL]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Кадры").font(.title3.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { (index, url) in
                        Button {
                            fullscreenIndex = index
                            fullscreenScreenshots = urls
                        } label: {
                            RemoteImage(url: url, contentMode: .fill) {
                                Rectangle().fill(Color.secondary.opacity(0.1))
                            }
                            .frame(width: 240, height: 135)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct Tag: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct VideoThumbnail: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RemoteImage(url: video.thumbnailURL, contentMode: .fill) {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.95))
            }
            Text(video.title ?? "Без названия")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(width: 240, alignment: .leading)
            if let host = video.hosting?.name {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

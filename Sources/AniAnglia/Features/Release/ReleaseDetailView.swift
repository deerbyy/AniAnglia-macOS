import SwiftUI

@MainActor
final class ReleaseDetailViewModel: ObservableObject {
    @Published var release: Release?
    @Published var videoBlocks: [VideoBlock] = []
    @Published var relatedCollections: [AnixartCollection] = []
    @Published var relatedReleases: [Release] = []
    @Published var relatedReleasesLoading = false
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
            await loadRelatedReleases(api: api, release: loadedRelease)
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

    func loadRelatedReleases(api: AnixartAPI, release: Release) async {
        let seed = relatedReleaseSearchSeed(for: release)
        guard !seed.isEmpty else {
            relatedReleases = []
            return
        }
        relatedReleasesLoading = true
        defer { relatedReleasesLoading = false }
        do {
            let response = try await api.searchReleases(query: seed, page: 0, searchBy: ReleaseSearchScope.title.rawValue)
            relatedReleases = response.items
                .filter { $0.id != release.id && isPotentiallyRelated($0, to: release) }
                .sorted(by: chronologicalReleaseSort)
        } catch {
            relatedReleases = []
        }
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

    private func relatedReleaseSearchSeed(for release: Release) -> String {
        let source = release.titleOriginal ?? release.titleRu ?? release.titleAlt ?? release.displayTitle
        let parts = source
            .replacingOccurrences(of: "—", with: ":")
            .replacingOccurrences(of: "-", with: ":")
            .split(separator: ":")
        let seed = String(parts.first ?? Substring(source))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return seed.isEmpty ? release.displayTitle : seed
    }

    private func isPotentiallyRelated(_ candidate: Release, to release: Release) -> Bool {
        let baseTokens = significantTitleTokens(for: release)
        let candidateTokens = significantTitleTokens(for: candidate)
        guard !baseTokens.isEmpty, !candidateTokens.isEmpty else { return false }
        let overlap = baseTokens.intersection(candidateTokens)
        if overlap.count >= min(2, baseTokens.count) { return true }
        let baseTitle = normalizedTitle(release.displayTitle)
        let candidateTitle = normalizedTitle(candidate.displayTitle)
        return baseTitle.count > 5 && (candidateTitle.contains(baseTitle) || baseTitle.contains(candidateTitle))
    }

    private func significantTitleTokens(for release: Release) -> Set<String> {
        let titles = [release.titleOriginal, release.titleRu, release.titleAlt, release.displayTitle]
        let stopwords: Set<String> = [
            "season", "сезон", "part", "часть", "movie", "film", "фильм", "ova", "ona",
            "special", "спешл", "tv", "the", "and", "no", "of", "s"
        ]
        var tokens: [String] = []
        for title in titles.compactMap({ $0 }) {
            for rawToken in normalizedTitle(title).split(separator: " ") {
                let token = String(rawToken)
                if token.count > 1, !stopwords.contains(token), Int(token) == nil {
                    tokens.append(token)
                }
            }
        }
        return Set(tokens)
    }

    private func normalizedTitle(_ title: String) -> String {
        title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func chronologicalReleaseSort(_ lhs: Release, _ rhs: Release) -> Bool {
        let lhsYear = Int(lhs.year ?? "") ?? Int.max
        let rhsYear = Int(rhs.year ?? "") ?? Int.max
        if lhsYear != rhsYear { return lhsYear < rhsYear }
        let lhsRank = releaseCategoryRank(lhs.category?.name)
        let rhsRank = releaseCategoryRank(rhs.category?.name)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
    }

    private func releaseCategoryRank(_ category: String?) -> Int {
        let value = category?.normalizedLibrarySearchQuery ?? ""
        if value.contains("сериал") || value.contains("tv") { return 0 }
        if value.contains("фильм") || value.contains("movie") { return 1 }
        if value.contains("ova") || value.contains("она") || value.contains("ona") { return 2 }
        if value.contains("спеш") || value.contains("special") { return 3 }
        return 4
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
                    overview(for: release)
                    if !release.screenshots.isEmpty {
                        screenshotsSection(urls: release.screenshots)
                    }
                    if !vm.relatedReleases.isEmpty || vm.relatedReleasesLoading {
                        relatedReleasesSection
                    }
                    if !vm.videoBlocks.isEmpty {
                        videosSection
                    }
                    if !vm.relatedCollections.isEmpty {
                        relatedCollectionsSection
                    }
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
                        .lineLimit(3)
                    if let original = release.titleOriginal, original != release.displayTitle {
                        Text(original)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    FlowLayout(spacing: 8, rowSpacing: 8) {
                        if let year = release.year { Tag(text: year, systemImage: "calendar") }
                        if let status = release.status?.name { Tag(text: status, systemImage: "dot.radiowaves.left.and.right") }
                        if let category = release.category?.name { Tag(text: category, systemImage: "rectangle.on.rectangle") }
                        if let grade = release.grade { Tag(text: String(format: "%.2f", grade), systemImage: "star.fill", tint: .yellow) }
                        if let voteCount = release.voteCount { Tag(text: "\(voteCount) оценок", systemImage: "person.2") }
                    }
                    releaseSummaryGrid(for: release)
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

    private func releaseSummaryGrid(for release: Release) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], alignment: .leading, spacing: 10) {
            releaseMetric("Оценка", release.grade.map { String(format: "%.2f", $0) }, "star.fill", .yellow)
            releaseMetric("Серии", episodeProgressText(for: release), "play.rectangle", .accentColor)
            releaseMetric("Тип", release.category?.name, "rectangle.on.rectangle", .secondary)
            releaseMetric("Статус", release.status?.name, "dot.radiowaves.left.and.right", .secondary)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func releaseMetric(_ title: String, _ value: String?, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(value?.nilIfBlank ?? "—")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func overview(for release: Release) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            releaseDescriptionSection(for: release)
            releaseInfoSection(for: release)
            genresSection(for: release)
        }
    }

    private func releaseDescriptionSection(for release: Release) -> some View {
        releaseSection(title: "Описание", icon: "text.alignleft") {
            Text(release.description?.nilIfBlank ?? "Описание отсутствует.")
                .font(.callout)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func releaseInfoSection(for release: Release) -> some View {
        let items = releaseInfoItems(for: release)
        if !items.isEmpty {
            releaseSection(title: "Информация", icon: "info.circle") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        ReleaseInfoTile(item: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func genresSection(for release: Release) -> some View {
        let genres = release.genreList
        if !genres.isEmpty {
            releaseSection(title: "Жанры", icon: "tag") {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(genres, id: \.self) { genre in
                        Tag(text: genre)
                    }
                }
            }
        }
    }

    private func releaseInfoItems(for release: Release) -> [ReleaseInfoItem] {
        [
            ReleaseInfoItem(title: "Оригинальное", value: release.titleOriginal, icon: "character.book.closed"),
            ReleaseInfoItem(title: "Альтернативное", value: release.titleAlt, icon: "textformat.abc"),
            ReleaseInfoItem(title: "Год выхода", value: release.year, icon: "calendar"),
            ReleaseInfoItem(title: "Формат", value: release.category?.name, icon: "rectangle.on.rectangle"),
            ReleaseInfoItem(title: "Статус", value: release.status?.name, icon: "dot.radiowaves.left.and.right"),
            ReleaseInfoItem(title: "Серии", value: episodeProgressText(for: release), icon: "play.rectangle"),
            ReleaseInfoItem(title: "Студия", value: release.studio, icon: "building.2"),
            ReleaseInfoItem(title: "Страна", value: release.country, icon: "globe.europe.africa"),
            ReleaseInfoItem(title: "Автор", value: release.author, icon: "pencil"),
            ReleaseInfoItem(title: "Режиссёр", value: release.director, icon: "megaphone"),
            ReleaseInfoItem(title: "Оценка", value: release.grade.map { String(format: "%.2f", $0) }, icon: "star"),
            ReleaseInfoItem(title: "Голосов", value: release.voteCount.map(String.init), icon: "person.2")
        ].compactMap { $0 }
    }

    private func episodeProgressText(for release: Release) -> String? {
        switch (release.episodesReleased, release.episodesTotal) {
        case (.some(let released), .some(let total)) where total > 0:
            return "\(released)/\(total)"
        case (.some(let released), _):
            return "\(released)"
        case (_, .some(let total)):
            return "\(total)"
        default:
            return nil
        }
    }

    private var videosSection: some View {
        let visibleBlocks = vm.filteredVideoBlocks
        return releaseSection(title: "Видео", icon: "film") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
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

    private var relatedReleasesSection: some View {
        releaseSection(title: "Связанные релизы", icon: "link") {
            if vm.relatedReleasesLoading && vm.relatedReleases.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(vm.relatedReleases) { release in
                            NavigationLink(value: release) {
                                RelatedReleaseCard(release: release)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 4)
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
        return releaseSection(title: "В коллекциях", icon: "rectangle.stack") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
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
        releaseSection(title: "Кадры", icon: "photo.on.rectangle") {
            Text("\(urls.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
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

    private func releaseSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Tag: View {
    let text: String
    var systemImage: String?
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .lineLimit(1)
        }
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct ReleaseInfoItem: Identifiable {
    let title: String
    let value: String
    let icon: String

    var id: String { "\(title)-\(value)" }

    init?(title: String, value: String?, icon: String) {
        guard let value = value?.nilIfBlank else { return nil }
        self.title = title
        self.value = value
        self.icon = icon
    }
}

private struct ReleaseInfoTile: View {
    let item: ReleaseInfoItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.value)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct RelatedReleaseCard: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ReleaseCard(release: release)
            FlowLayout(spacing: 6, rowSpacing: 6) {
                if let year = release.year {
                    Tag(text: year, systemImage: "calendar")
                }
                if let category = release.category?.name {
                    Tag(text: category, systemImage: "rectangle.on.rectangle")
                }
                if let status = release.status?.name {
                    Tag(text: status, systemImage: "dot.radiowaves.left.and.right")
                }
            }
            .frame(width: 160, alignment: .leading)
        }
        .frame(width: 160, alignment: .leading)
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

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrangedRows(subviews: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        return CGSize(width: maxWidth.isFinite ? min(width, maxWidth) : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangedRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.size
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrangedRows(subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var current = FlowRow()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = FlowRow()
            }
            current.items.append(FlowItem(index: index, size: size))
            current.width = current.items.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct FlowItem {
        let index: Int
        let size: CGSize
    }

    private struct FlowRow {
        var items: [FlowItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
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

private extension Release {
    var genreList: [String] {
        guard let genres else { return [] }
        return genres
            .split { [",", ";", "/", "|"].contains(String($0)) }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

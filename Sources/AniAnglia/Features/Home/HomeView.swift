import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var watching: [Release] = []
    @Published var recommendations: [Release] = []
    @Published var continueWatching: [Release] = []
    @Published var discussing: [Release] = []
    @Published var commentsWeek: [ReleaseComment] = []
    @Published var weekCollections: [AnixartCollection] = []
    @Published var isLoading = false
    @Published var isLoadingMoreWatching = false
    @Published var isLoadingMoreRecommendations = false
    @Published var isLoadingMoreDiscussing = false
    @Published var isLoadingMoreWeekCollections = false
    @Published var errorMessage: String?

    private var watchingPage = 0
    private var recommendationsPage = 0
    private var discussingPage = 0
    private var weekCollectionsPage = 0
    private var watchingReachedEnd = false
    private var recommendationsReachedEnd = false
    private var discussingReachedEnd = false
    private var weekCollectionsReachedEnd = false

    var canLoadMoreWatching: Bool {
        !isLoading && !isLoadingMoreWatching && !watchingReachedEnd
    }

    var canLoadMoreRecommendations: Bool {
        !isLoading && !isLoadingMoreRecommendations && !recommendationsReachedEnd
    }

    var canLoadMoreDiscussing: Bool {
        !isLoading && !isLoadingMoreDiscussing && !discussingReachedEnd
    }

    var canLoadMoreWeekCollections: Bool {
        !isLoading && !isLoadingMoreWeekCollections && !weekCollectionsReachedEnd
    }

    func load(api: AnixartAPI) async {
        isLoading = true
        resetPaging()
        var initialWatchingItems: [Release] = []
        do {
            let watchingResp = try await api.discoverWatching(page: 0)
            initialWatchingItems = watchingResp.items
            self.watching = initialWatchingItems
            watchingPage = 1
            watchingReachedEnd = reachedEnd(page: 0, totalPageCount: watchingResp.totalPageCount, incomingIsEmpty: watchingResp.items.isEmpty)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            watchingReachedEnd = true
        }
        if let discussingResp = try? await api.discoverDiscussing() {
            self.discussing = deduplicated(discussingResp.items + initialWatchingItems)
        } else {
            self.discussing = initialWatchingItems
        }
        discussingPage = 1
        discussingReachedEnd = watchingReachedEnd
        if let commentsResp = try? await api.discoverCommentsWeek() {
            self.commentsWeek = commentsResp.content
        } else {
            self.commentsWeek = []
        }
        if let collectionsResp = try? await api.discoverWeekCollections(page: 0) {
            self.weekCollections = collectionsResp.items
            weekCollectionsPage = 1
            weekCollectionsReachedEnd = reachedEnd(
                page: 0,
                totalPageCount: collectionsResp.totalPageCount,
                incomingIsEmpty: collectionsResp.items.isEmpty
            )
        } else {
            self.weekCollections = []
            weekCollectionsReachedEnd = true
        }
        // Personal recommendations only when authed (don't fail the whole load if this fails).
        if api.auth.isAuthenticated {
            if let response = try? await api.discoverRecommendations(page: 0) {
                self.recommendations = response.items
                recommendationsPage = 1
                recommendationsReachedEnd = reachedEnd(
                    page: 0,
                    totalPageCount: response.totalPageCount,
                    incomingIsEmpty: response.items.isEmpty
                )
            } else {
                recommendations = []
                recommendationsReachedEnd = true
            }
            if let historyResponse = try? await api.watchHistory(page: 0) {
                self.continueWatching = deduplicated(historyResponse.items)
            } else {
                self.continueWatching = []
            }
        } else {
            self.recommendations = []
            self.continueWatching = []
            recommendationsReachedEnd = true
        }
        isLoading = false
    }

    func loadMoreWatching(api: AnixartAPI) async {
        guard canLoadMoreWatching else { return }
        isLoadingMoreWatching = true
        defer { isLoadingMoreWatching = false }
        do {
            let page = watchingPage
            let response = try await api.discoverWatching(page: page)
            watching = deduplicated(watching + response.items)
            watchingPage = page + 1
            watchingReachedEnd = reachedEnd(
                page: page,
                totalPageCount: response.totalPageCount,
                incomingIsEmpty: response.items.isEmpty
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreRecommendations(api: AnixartAPI) async {
        guard api.auth.isAuthenticated, canLoadMoreRecommendations else { return }
        isLoadingMoreRecommendations = true
        defer { isLoadingMoreRecommendations = false }
        do {
            let page = recommendationsPage
            let response = try await api.discoverRecommendations(page: page)
            recommendations = deduplicated(recommendations + response.items)
            recommendationsPage = page + 1
            recommendationsReachedEnd = reachedEnd(
                page: page,
                totalPageCount: response.totalPageCount,
                incomingIsEmpty: response.items.isEmpty
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreDiscussing(api: AnixartAPI) async {
        guard canLoadMoreDiscussing else { return }
        isLoadingMoreDiscussing = true
        defer { isLoadingMoreDiscussing = false }
        do {
            let page = discussingPage
            let response = try await api.discoverWatching(page: page)
            discussing = deduplicated(discussing + response.items)
            discussingPage = page + 1
            discussingReachedEnd = reachedEnd(
                page: page,
                totalPageCount: response.totalPageCount,
                incomingIsEmpty: response.items.isEmpty
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreWeekCollections(api: AnixartAPI) async {
        guard canLoadMoreWeekCollections else { return }
        isLoadingMoreWeekCollections = true
        defer { isLoadingMoreWeekCollections = false }
        do {
            let page = weekCollectionsPage
            let response = try await api.discoverWeekCollections(page: page)
            weekCollections = deduplicatedCollections(weekCollections + response.items)
            weekCollectionsPage = page + 1
            weekCollectionsReachedEnd = reachedEnd(
                page: page,
                totalPageCount: response.totalPageCount,
                incomingIsEmpty: response.items.isEmpty
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetPaging() {
        watchingPage = 0
        recommendationsPage = 0
        discussingPage = 0
        weekCollectionsPage = 0
        watchingReachedEnd = false
        recommendationsReachedEnd = false
        discussingReachedEnd = false
        weekCollectionsReachedEnd = false
        isLoadingMoreWatching = false
        isLoadingMoreRecommendations = false
        isLoadingMoreDiscussing = false
        isLoadingMoreWeekCollections = false
    }

    private func reachedEnd(page: Int, totalPageCount: Int?, incomingIsEmpty: Bool) -> Bool {
        if let totalPageCount {
            return page + 1 >= totalPageCount
        }
        return incomingIsEmpty
    }

    private func deduplicated(_ releases: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return releases.filter { release in
            seen.insert(release.id).inserted
        }
    }

    private func deduplicatedCollections(_ collections: [AnixartCollection]) -> [AnixartCollection] {
        var seen = Set<Int64>()
        return collections.filter { collection in
            seen.insert(collection.id).inserted
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HomeViewModel()
    @State private var weeklyCommentSearchQuery = ""
    @State private var showsAllWeeklyComments = false

    private var filteredWeeklyComments: [ReleaseComment] {
        vm.commentsWeek.filter { $0.matchesCommentQuery(weeklyCommentSearchQuery) }
    }

    private var hasWeeklyCommentSearchQuery: Bool {
        !weeklyCommentSearchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if vm.isLoading && vm.watching.isEmpty {
                    ProgressView("Загрузка…")
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage, vm.watching.isEmpty {
                    ErrorState(message: error) {
                        Task { await vm.load(api: appState.api) }
                    }
                } else {
                    if !vm.continueWatching.isEmpty {
                        continueWatchingSection
                    }
                    if !vm.recommendations.isEmpty {
                        section(
                            title: "Рекомендации",
                            releases: vm.recommendations,
                            canLoadMore: vm.canLoadMoreRecommendations,
                            isLoadingMore: vm.isLoadingMoreRecommendations
                        ) {
                            Task { await vm.loadMoreRecommendations(api: appState.api) }
                        }
                    }
                    if !vm.discussing.isEmpty {
                        section(
                            title: "Актуальное обсуждают",
                            releases: vm.discussing,
                            canLoadMore: vm.canLoadMoreDiscussing,
                            isLoadingMore: vm.isLoadingMoreDiscussing
                        ) {
                            Task { await vm.loadMoreDiscussing(api: appState.api) }
                        }
                    }
                    section(
                        title: "Сейчас смотрят",
                        releases: vm.watching,
                        canLoadMore: vm.canLoadMoreWatching,
                        isLoadingMore: vm.isLoadingMoreWatching
                    ) {
                        Task { await vm.loadMoreWatching(api: appState.api) }
                    }
                    if !vm.weekCollections.isEmpty {
                        collectionsSection
                    }
                    if !vm.commentsWeek.isEmpty {
                        commentsSection
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Главная")
        .task { await vm.load(api: appState.api) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.load(api: appState.api) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Обновить")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AniAnglia")
                    .font(.system(size: 28, weight: .bold))
                Text("Неофициальный клиент Anixart для macOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func section(
        title: String,
        releases: [Release],
        canLoadMore: Bool = false,
        isLoadingMore: Bool = false,
        onLoadMore: (() -> Void)? = nil
    ) -> some View {
        HomeReleaseRail(
            title: title,
            releases: releases,
            canLoadMore: canLoadMore,
            isLoadingMore: isLoadingMore,
            onLoadMore: onLoadMore
        )
    }

    private var continueWatchingSection: some View {
        HomeReleaseRail(
            title: "Продолжить просмотр",
            releases: vm.continueWatching,
            showsCount: true,
            trailingTitle: "Вся история",
            trailingAction: {
                appState.selectedSidebar = .history
            }
        )
    }

    @ViewBuilder
    private var commentsSection: some View {
        let comments = filteredWeeklyComments
        let visibleComments = showsAllWeeklyComments ? comments : Array(comments.prefix(6))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Комментарии недели")
                    .font(.title3.bold())
                Text("\(comments.count) из \(vm.commentsWeek.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if comments.count > 6 {
                    Button(showsAllWeeklyComments ? "Свернуть" : "Все") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsAllWeeklyComments.toggle()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Поиск по комментариям, авторам и релизам", text: $weeklyCommentSearchQuery)
                    .textFieldStyle(.plain)
                if hasWeeklyCommentSearchQuery {
                    Button {
                        weeklyCommentSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Очистить поиск")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if visibleComments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ничего не найдено")
                        .font(.callout.weight(.semibold))
                    Text("Попробуй другой текст, автора или название релиза.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleComments) { comment in
                        WeeklyCommentRow(comment: comment)
                    }
                }

                if !showsAllWeeklyComments && comments.count > visibleComments.count {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsAllWeeklyComments = true
                        }
                    } label: {
                        Label("Показать ещё \(comments.count - visibleComments.count)", systemImage: "chevron.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var collectionsSection: some View {
        HomeCollectionRail(
            title: "Коллекции недели",
            collections: vm.weekCollections,
            canLoadMore: vm.canLoadMoreWeekCollections,
            isLoadingMore: vm.isLoadingMoreWeekCollections,
            trailingTitle: "Все",
            trailingAction: {
                appState.selectedSidebar = .collections
            },
            onLoadMore: {
                Task { await vm.loadMoreWeekCollections(api: appState.api) }
            }
        )
    }
}

private enum HomeRailTarget: Hashable {
    case release(Int64)
    case collection(Int64)
    case loadMore
}

private struct HomeReleaseRail: View {
    let title: String
    let releases: [Release]
    var showsCount = false
    var canLoadMore = false
    var isLoadingMore = false
    var trailingTitle: String?
    var trailingAction: (() -> Void)?
    var onLoadMore: (() -> Void)?

    @State private var focusedIndex = 0

    private let pageStep = 4

    private var targetCount: Int {
        releases.count + (showsLoadMore ? 1 : 0)
    }

    private var showsLoadMore: Bool {
        canLoadMore || isLoadingMore
    }

    private var lastIndex: Int {
        max(targetCount - 1, 0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HomeRailHeader(
                    title: title,
                    count: showsCount ? releases.count : nil,
                    trailingTitle: trailingTitle,
                    trailingAction: trailingAction,
                    canMoveBackward: focusedIndex > 0,
                    canMoveForward: focusedIndex < lastIndex,
                    onStart: { scroll(to: 0, proxy: proxy) },
                    onPrevious: { scroll(by: -pageStep, proxy: proxy) },
                    onNext: { scroll(by: pageStep, proxy: proxy) },
                    onEnd: { scroll(to: lastIndex, proxy: proxy) }
                )

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(releases) { release in
                            NavigationLink(value: release) {
                                ReleaseCard(release: release)
                            }
                            .buttonStyle(.plain)
                            .id(HomeRailTarget.release(release.id))
                        }

                        if showsLoadMore {
                            Button {
                                onLoadMore?()
                            } label: {
                                HomeLoadMoreCard(
                                    title: "Показать ещё",
                                    isLoading: isLoadingMore,
                                    width: 160,
                                    height: 230
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingMore)
                            .id(HomeRailTarget.loadMore)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .onChange(of: targetCount) { _ in
                focusedIndex = min(focusedIndex, lastIndex)
            }
        }
    }

    private func scroll(by delta: Int, proxy: ScrollViewProxy) {
        scroll(to: focusedIndex + delta, proxy: proxy)
    }

    private func scroll(to index: Int, proxy: ScrollViewProxy) {
        guard targetCount > 0 else { return }
        let nextIndex = min(max(index, 0), lastIndex)
        focusedIndex = nextIndex
        guard let target = target(at: nextIndex) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .leading)
        }
    }

    private func target(at index: Int) -> HomeRailTarget? {
        guard index >= 0, index < targetCount else { return nil }
        if index < releases.count {
            return .release(releases[index].id)
        }
        return .loadMore
    }
}

private struct HomeCollectionRail: View {
    let title: String
    let collections: [AnixartCollection]
    var canLoadMore = false
    var isLoadingMore = false
    var trailingTitle: String?
    var trailingAction: (() -> Void)?
    var onLoadMore: (() -> Void)?

    @State private var focusedIndex = 0

    private let pageStep = 3

    private var targetCount: Int {
        collections.count + (showsLoadMore ? 1 : 0)
    }

    private var showsLoadMore: Bool {
        canLoadMore || isLoadingMore
    }

    private var lastIndex: Int {
        max(targetCount - 1, 0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HomeRailHeader(
                    title: title,
                    count: nil,
                    trailingTitle: trailingTitle,
                    trailingAction: trailingAction,
                    canMoveBackward: focusedIndex > 0,
                    canMoveForward: focusedIndex < lastIndex,
                    onStart: { scroll(to: 0, proxy: proxy) },
                    onPrevious: { scroll(by: -pageStep, proxy: proxy) },
                    onNext: { scroll(by: pageStep, proxy: proxy) },
                    onEnd: { scroll(to: lastIndex, proxy: proxy) }
                )

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(collections) { collection in
                            NavigationLink(value: CollectionRoute(collection)) {
                                CollectionCard(collection: collection, style: .compact)
                            }
                            .buttonStyle(.plain)
                            .id(HomeRailTarget.collection(collection.id))
                        }

                        if showsLoadMore {
                            Button {
                                onLoadMore?()
                            } label: {
                                HomeLoadMoreCard(
                                    title: "Показать ещё",
                                    isLoading: isLoadingMore,
                                    width: 220,
                                    height: 124
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingMore)
                            .id(HomeRailTarget.loadMore)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .onChange(of: targetCount) { _ in
                focusedIndex = min(focusedIndex, lastIndex)
            }
        }
    }

    private func scroll(by delta: Int, proxy: ScrollViewProxy) {
        scroll(to: focusedIndex + delta, proxy: proxy)
    }

    private func scroll(to index: Int, proxy: ScrollViewProxy) {
        guard targetCount > 0 else { return }
        let nextIndex = min(max(index, 0), lastIndex)
        focusedIndex = nextIndex
        guard let target = target(at: nextIndex) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .leading)
        }
    }

    private func target(at index: Int) -> HomeRailTarget? {
        guard index >= 0, index < targetCount else { return nil }
        if index < collections.count {
            return .collection(collections[index].id)
        }
        return .loadMore
    }
}

private struct HomeRailHeader: View {
    let title: String
    let count: Int?
    let trailingTitle: String?
    let trailingAction: (() -> Void)?
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onStart: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.title3.bold())
            if let count {
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let trailingTitle, let trailingAction {
                Button(trailingTitle, action: trailingAction)
                    .buttonStyle(.borderless)
            }
            HomeRailControls(
                canMoveBackward: canMoveBackward,
                canMoveForward: canMoveForward,
                onStart: onStart,
                onPrevious: onPrevious,
                onNext: onNext,
                onEnd: onEnd
            )
        }
    }
}

private struct HomeRailControls: View {
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onStart: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            railButton(systemName: "backward.end.fill", help: "В начало", isEnabled: canMoveBackward, action: onStart)
            railButton(systemName: "chevron.left", help: "Назад", isEnabled: canMoveBackward, action: onPrevious)
            railButton(systemName: "chevron.right", help: "Вперёд", isEnabled: canMoveForward, action: onNext)
            railButton(systemName: "forward.end.fill", help: "В конец", isEnabled: canMoveForward, action: onEnd)
        }
        .controlSize(.small)
    }

    private func railButton(systemName: String, help: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
        .help(help)
    }
}

private struct HomeLoadMoreCard: View {
    let title: String
    let isLoading: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .frame(width: width, height: height)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WeeklyCommentRow: View {
    let comment: ReleaseComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAuthorAvatarLink(profile: comment.profile, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    CommentAuthorNameLink(profile: comment.profile, font: .callout.bold())
                    if !comment.formattedDate.isEmpty {
                        Text(comment.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let score = comment.voteCount {
                        Label(String(score), systemImage: "hand.thumbsup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                originLink
                Text(comment.isSpoiler == true ? "Спойлер" : comment.message)
                    .font(.callout)
                    .foregroundStyle(comment.isSpoiler == true ? .secondary : .primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var originLink: some View {
        if let release = comment.release {
            NavigationLink(value: release) {
                Text(comment.originTitle ?? release.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Открыть релиз")
        } else if let collection = comment.collection {
            NavigationLink(value: CollectionRoute(collection)) {
                Text(comment.originTitle ?? collection.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Открыть коллекцию")
        }
    }
}

struct ErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text("Не удалось загрузить")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Повторить", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

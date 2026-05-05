import SwiftUI

@MainActor
final class ReleaseDetailViewModel: ObservableObject {
    @Published var release: ReleaseDetail?
    @Published var episodes: [Episode] = []
    @Published var videos: [VideoBlock] = []
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isDescriptionExpanded = false
    @Published var errorMessage: String?
    @Published var playerSession: PlayerSession?
    @Published var fullscreenImageURL: IdentifiedURL?

    private var loadedID: Int?

    func load(releaseID: Int, api: AnixartAPIClient, force: Bool = false) async {
        guard force || loadedID != releaseID else { return }
        loadedID = releaseID
        isLoading = true
        errorMessage = nil
        do {
            async let release = api.release(id: releaseID)
            async let episodes = api.episodes(releaseID: releaseID)
            async let videos = api.videos(releaseID: releaseID)
            async let comments = api.comments(releaseID: releaseID, page: 0)
            self.release = try await release
            self.episodes = try await episodes.episodes
            self.videos = try await videos
            self.comments = try await comments.comments
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addFavorite(category: FavoriteCategory, api: AnixartAPIClient) async {
        guard let release else { return }
        do {
            try await api.addFavorite(releaseID: release.id, category: category)
            try await api.editWatchStatus(releaseID: release.id, status: WatchListStatus(rawValue: category.rawValue) ?? .planned)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFavorite(api: AnixartAPIClient) async {
        guard let release else { return }
        do {
            try await api.deleteFavorite(releaseID: release.id)
            try await api.editWatchStatus(releaseID: release.id, status: .none)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openEpisode(_ episode: Episode, source: EpisodeSource, api: AnixartAPIClient) async {
        guard let release else { return }
        do {
            let player = try await api.episodePlayer(releaseID: release.id, sourceID: source.id, episodeID: episode.id)
            guard let url = URL.web(player.url) else {
                errorMessage = "Источник не вернул URL плеера."
                return
            }
            playerSession = PlayerSession(title: "\(release.displayTitle) - \(episode.name)", url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openVideo(_ video: ReleaseVideo) {
        guard let url = URL.web(video.playerUrl ?? video.url) else {
            errorMessage = "У видео нет доступного URL."
            return
        }
        playerSession = PlayerSession(title: video.title, url: url)
    }
}

struct ReleaseDetailView: View {
    let releaseID: Int

    @Environment(\.anixartAPI) private var api
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var imageCache: ImageCache
    @StateObject private var viewModel = ReleaseDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.release == nil {
                LoadingStateView(title: "Загружаем релиз")
            } else if let release = viewModel.release {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        header(release)
                        description(release)
                        episodesSection
                        screenshotsSection(release)
                        videosSection
                        commentsSection
                    }
                    .padding(24)
                    .frame(maxWidth: 1180, alignment: .leading)
                }
            } else {
                EmptyStateView(systemImage: "film", title: "Релиз недоступен", message: viewModel.errorMessage ?? "Не удалось загрузить данные.")
            }
        }
        .task(id: releaseID) {
            await viewModel.load(releaseID: releaseID, api: api)
        }
        .toolbar {
            Button {
                Task { await viewModel.load(releaseID: releaseID, api: api, force: true) }
            } label: {
                Label("Обновить", systemImage: "arrow.clockwise")
            }
        }
        .sheet(item: $viewModel.playerSession) { session in
            VideoPlayerSheet(session: session)
        }
        .sheet(item: $viewModel.fullscreenImageURL) { url in
            PosterZoomView(url: url.url)
                .environmentObject(imageCache)
        }
    }

    private func header(_ release: ReleaseDetail) -> some View {
        HStack(alignment: .top, spacing: 24) {
            CachedRemoteImage(urlString: release.summary.image)
                .frame(width: 230, height: 326)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator.opacity(0.35), lineWidth: 1)
                }
                .onTapGesture(count: 2) {
                    viewModel.fullscreenImageURL = URL.web(release.summary.image).map(IdentifiedURL.init(url:))
                }

            VStack(alignment: .leading, spacing: 14) {
                Text(release.displayTitle)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(3)

                if let original = release.summary.titleOriginal.nonEmpty, original != release.displayTitle {
                    Text(original)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let year = release.summary.year {
                        Chip(String(year))
                    }
                    if let country = release.country.nonEmpty {
                        Chip(country)
                    }
                    if let status = release.summary.status.nonEmpty {
                        Chip(status)
                    }
                    if let grade = release.summary.grade {
                        Chip("Рейтинг \(grade.gradeText)")
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    infoRow("Студия", release.studio)
                    infoRow("Режиссер", release.director)
                    if let released = release.summary.episodesReleased {
                        infoRow("Эпизоды", "\(released)/\(release.summary.episodesTotal ?? released)")
                    }
                }

                genreRow(release.summary.genres)

                bookmarkMenu
            }
        }
    }

    private func infoRow(_ title: String, _ value: String?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            Text(value.nonEmpty ?? "Не указано")
        }
        .font(.callout)
    }

    private func genreRow(_ genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Chip(genre)
                }
            }
        }
    }

    private var bookmarkMenu: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(FavoriteCategory.allCases) { category in
                    Button(category.title) {
                        Task { await viewModel.addFavorite(category: category, api: api) }
                    }
                }
                Divider()
                Button("Удалить из закладок") {
                    Task { await viewModel.deleteFavorite(api: api) }
                }
            } label: {
                Label("Добавить в закладки", systemImage: "bookmark")
            }
            .disabled(!authStore.isAuthenticated)

            if !authStore.isAuthenticated {
                Text("Доступно после входа")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func description(_ release: ReleaseDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Описание")
                .font(.title3.weight(.semibold))

            Text(release.description.nonEmpty ?? "Описание пока не добавлено.")
                .lineLimit(viewModel.isDescriptionExpanded ? nil : 5)
                .textSelection(.enabled)

            Button(viewModel.isDescriptionExpanded ? "Свернуть" : "Показать полностью") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isDescriptionExpanded.toggle()
                }
            }
            .buttonStyle(.link)
        }
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Эпизоды")
                .font(.title3.weight(.semibold))

            if viewModel.episodes.isEmpty {
                Text("Эпизоды не найдены.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.episodes) { episode in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(episode.position ?? episode.id)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)

                            Text(episode.name)
                                .lineLimit(2)

                            Spacer()

                            ForEach(episode.sources) { source in
                                Button(source.name) {
                                    Task { await viewModel.openEpisode(episode, source: source, api: api) }
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private func screenshotsSection(_ release: ReleaseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Скриншоты")
                .font(.title3.weight(.semibold))

            if release.screenshotImageUrls.isEmpty {
                Text("Скриншоты не найдены.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(release.screenshotImageUrls, id: \.self) { screenshot in
                            CachedRemoteImage(urlString: screenshot)
                                .frame(width: 240, height: 135)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onTapGesture(count: 2) {
                                    viewModel.fullscreenImageURL = URL.web(screenshot).map(IdentifiedURL.init(url:))
                                }
                        }
                    }
                }
            }
        }
    }

    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Видео")
                .font(.title3.weight(.semibold))

            if viewModel.videos.isEmpty {
                Text("Видео не найдено.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.videos) { block in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(block.category.name)
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(block.videos) { video in
                                    Button {
                                        viewModel.openVideo(video)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            CachedRemoteImage(urlString: video.image)
                                                .frame(width: 220, height: 124)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            Text(video.title)
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                                .frame(width: 220, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Комментарии")
                .font(.title3.weight(.semibold))

            if viewModel.comments.isEmpty {
                Text("Комментариев пока нет.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(comment.profile?.displayName ?? "Аноним")
                                .font(.headline)
                            Spacer()
                            Label(comment.votesCount.compactText, systemImage: "hand.thumbsup")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(comment.message)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

struct IdentifiedURL: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct PosterZoomView: View {
    let url: URL
    @EnvironmentObject private var imageCache: ImageCache
    @State private var image: NSImage?
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(DragGesture().onChanged { offset = $0.translation })
                    .onTapGesture(count: 2) {
                        withAnimation {
                            scale = scale == 1 ? 2 : 1
                            if scale == 1 { offset = .zero }
                        }
                    }
                    .padding()
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .task {
            image = try? await imageCache.image(for: url)
        }
    }
}

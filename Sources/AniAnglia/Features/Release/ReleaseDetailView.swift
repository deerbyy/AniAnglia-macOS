import SwiftUI

@MainActor
final class ReleaseDetailViewModel: ObservableObject {
    @Published var release: Release?
    @Published var videoBlocks: [VideoBlock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(api: AnixartAPI, releaseId: Int64) async {
        isLoading = true
        defer { isLoading = false }
        async let releaseTask: Release? = {
            do { return try await api.release(id: releaseId) }
            catch { return nil }
        }()
        async let videosTask: [VideoBlock] = {
            do { return try await api.videoBlocks(releaseId: releaseId).blocks }
            catch { return [] }
        }()
        let (loadedRelease, loadedBlocks) = await (releaseTask, videosTask)
        if let loadedRelease {
            release = loadedRelease
        }
        videoBlocks = loadedBlocks
        if release == nil && errorMessage == nil {
            errorMessage = "Не удалось загрузить релиз"
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
                    if !release.screenshots.isEmpty {
                        screenshotsSection(urls: release.screenshots)
                    }
                    description(for: release)
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
                }
                Spacer()
            }
            Spacer()
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Видео").font(.title3.bold())
            ForEach(vm.videoBlocks) { block in
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

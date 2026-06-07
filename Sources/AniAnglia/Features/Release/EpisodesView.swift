import SwiftUI

enum EpisodeListFilter: String, CaseIterable, Identifiable {
    case all
    case unwatched
    case watched

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Все"
        case .unwatched: return "Не просмотрено"
        case .watched: return "Просмотрено"
        }
    }
}

fileprivate struct EpisodePlaybackSession: Identifiable {
    let id = UUID()
    let episodes: [Episode]
    var currentIndex: Int

    init(episodes: [Episode], current episode: Episode) {
        let candidates = episodes.isEmpty ? [episode] : episodes
        self.episodes = candidates
        self.currentIndex = candidates.firstIndex(where: { $0.id == episode.id }) ?? 0
    }

    var currentEpisode: Episode {
        episodes[currentIndex]
    }

    var previousIndex: Int? {
        currentIndex > episodes.startIndex ? currentIndex - 1 : nil
    }

    var nextIndex: Int? {
        let next = currentIndex + 1
        return episodes.indices.contains(next) ? next : nil
    }

    func firstLaterUnwatchedIndex(isWatched: (Episode) -> Bool) -> Int? {
        for index in episodes.indices where index > currentIndex && !isWatched(episodes[index]) {
            return index
        }
        return nil
    }
}

@MainActor
final class EpisodesViewModel: ObservableObject {
    let releaseId: Int64
    @Published var types: [EpisodeType] = []
    @Published var sources: [EpisodeSource] = []
    @Published var episodes: [Episode] = []
    @Published var selectedTypeId: Int?
    @Published var selectedSourceId: Int?
    @Published var isLoadingTypes = false
    @Published var isLoadingSources = false
    @Published var isLoadingEpisodes = false
    @Published var errorMessage: String?
    /// Locally toggled watched state, keyed by Episode.id.
    @Published var watchedOverrides: [String: Bool] = [:]
    @Published var filter: EpisodeListFilter = .all
    @Published var searchQuery = ""

    init(releaseId: Int64) { self.releaseId = releaseId }

    var filteredEpisodes: [Episode] {
        episodes.filter { episode in
            let statusMatches: Bool
            switch filter {
            case .all:
                statusMatches = true
            case .unwatched:
                statusMatches = !isWatched(episode)
            case .watched:
                statusMatches = isWatched(episode)
            }
            return statusMatches && episode.matchesEpisodeQuery(searchQuery)
        }
    }

    var hasSearchQuery: Bool {
        !searchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    var watchedCount: Int {
        episodes.filter { isWatched($0) }.count
    }

    var firstUnwatchedEpisode: Episode? {
        episodes.first { !isWatched($0) }
    }

    func isWatched(_ episode: Episode) -> Bool {
        if let v = watchedOverrides[episode.id] { return v }
        return episode.isWatched == true
    }

    func toggleWatched(_ episode: Episode, api: AnixartAPI) async {
        let nextWatched = !isWatched(episode)
        watchedOverrides[episode.id] = nextWatched
        do {
            if nextWatched {
                _ = try await api.markEpisodeWatched(releaseId: episode.releaseId, sourceId: episode.sourceId, position: episode.position)
            } else {
                _ = try await api.unmarkEpisodeWatched(releaseId: episode.releaseId, sourceId: episode.sourceId, position: episode.position)
            }
        } catch {
            // Revert on failure
            watchedOverrides[episode.id] = !nextWatched
            errorMessage = error.localizedDescription
        }
    }

    func markWatched(_ episode: Episode, api: AnixartAPI) async {
        guard !isWatched(episode) else { return }
        let previousOverride = watchedOverrides[episode.id]
        watchedOverrides[episode.id] = true
        do {
            _ = try await api.markEpisodeWatched(releaseId: episode.releaseId, sourceId: episode.sourceId, position: episode.position)
        } catch {
            if let previousOverride {
                watchedOverrides[episode.id] = previousOverride
            } else {
                watchedOverrides.removeValue(forKey: episode.id)
            }
            errorMessage = error.localizedDescription
        }
    }

    func loadTypes(api: AnixartAPI) async {
        isLoadingTypes = true
        defer { isLoadingTypes = false }
        do {
            let list = try await api.episodeTypes(releaseId: releaseId)
            types = list
            errorMessage = nil
            // Pick pinned or first
            if let firstPinned = list.first(where: { $0.pinned == true }) ?? list.first {
                selectedTypeId = firstPinned.id
                await loadSources(api: api, typeId: firstPinned.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSources(api: AnixartAPI, typeId: Int) async {
        selectedTypeId = typeId
        sources = []
        episodes = []
        selectedSourceId = nil
        isLoadingSources = true
        defer { isLoadingSources = false }
        do {
            let list = try await api.episodeSources(releaseId: releaseId, typeId: typeId)
            sources = list
            if let first = list.first(where: { $0.pinned == true }) ?? list.first {
                selectedSourceId = first.id
                await loadEpisodes(api: api, typeId: typeId, sourceId: first.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEpisodes(api: AnixartAPI, typeId: Int, sourceId: Int) async {
        selectedSourceId = sourceId
        episodes = []
        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }
        do {
            let list = try await api.episodes(releaseId: releaseId, typeId: typeId, sourceId: sourceId)
            episodes = list.sorted { $0.position < $1.position }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct EpisodesView: View {
    let releaseId: Int64
    let releaseTitle: String?

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: EpisodesViewModel
    @State private var playbackSession: EpisodePlaybackSession?

    init(releaseId: Int64, releaseTitle: String? = nil) {
        self.releaseId = releaseId
        self.releaseTitle = releaseTitle
        _vm = StateObject(wrappedValue: EpisodesViewModel(releaseId: releaseId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !vm.types.isEmpty { typesPicker }
            if !vm.sources.isEmpty { sourcesPicker }
            if !vm.episodes.isEmpty { episodeControls }
            Divider()
            content
        }
        .padding(20)
        .navigationTitle(releaseTitle ?? "Серии")
        .task { await vm.loadTypes(api: appState.api) }
        .sheet(item: $playbackSession) { session in
            EpisodePlayerSheet(
                session: session,
                releaseTitle: releaseTitle,
                isWatched: { episode in vm.isWatched(episode) },
                onMarkWatched: { episode in
                    guard appState.auth.isAuthenticated else { return }
                    await vm.markWatched(episode, api: appState.api)
                }
            )
        }
    }

    private var episodeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                episodeSearchField
                if let nextEpisode = vm.firstUnwatchedEpisode {
                    Button {
                        openPlayback(nextEpisode, episodes: vm.episodes)
                    } label: {
                        Label("Продолжить", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Открыть первую непросмотренную серию")
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Picker("Фильтр", selection: $vm.filter) {
                    ForEach(EpisodeListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 390)

                Text("\(vm.filteredEpisodes.count)/\(vm.episodes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("просмотрено \(vm.watchedCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var episodeSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск по сериям", text: $vm.searchQuery)
                .textFieldStyle(.plain)
            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
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

    private var typesPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Озвучка")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.types) { type in
                        chip(
                            title: type.name,
                            subtitle: type.workers,
                            count: type.episodesCount,
                            isSelected: vm.selectedTypeId == type.id
                        ) {
                            Task { await vm.loadSources(api: appState.api, typeId: type.id) }
                        }
                    }
                }
            }
        }
    }

    private var sourcesPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Плеер")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.sources) { source in
                        chip(
                            title: source.name,
                            subtitle: nil,
                            count: source.episodesCount,
                            isSelected: vm.selectedSourceId == source.id
                        ) {
                            if let typeId = vm.selectedTypeId {
                                Task { await vm.loadEpisodes(api: appState.api, typeId: typeId, sourceId: source.id) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func chip(title: String, subtitle: String?, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.callout.bold())
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoadingTypes || vm.isLoadingSources || vm.isLoadingEpisodes {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage, vm.episodes.isEmpty {
            ErrorState(message: error) {
                Task { await vm.loadTypes(api: appState.api) }
            }
        } else if vm.episodes.isEmpty {
            Text("У этого релиза пока нет серий в выбранной озвучке/плеере.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        } else if vm.filteredEpisodes.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Серии не найдены")
                    .font(.headline)
                Text("Измени поиск или фильтр просмотра.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.filteredEpisodes) { episode in
                        EpisodeRow(
                            episode: episode,
                            isWatched: vm.isWatched(episode),
                            canMark: appState.auth.isAuthenticated,
                            onPlay: { openPlayback(episode) },
                            onToggleWatched: {
                                Task { await vm.toggleWatched(episode, api: appState.api) }
                            }
                        )
                        Divider()
                    }
                }
            }
        }
    }

    private func openPlayback(_ episode: Episode, episodes: [Episode]? = nil) {
        let candidates = episodes ?? vm.filteredEpisodes
        playbackSession = EpisodePlaybackSession(episodes: candidates, current: episode)
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let isWatched: Bool
    let canMark: Bool
    let onPlay: () -> Void
    let onToggleWatched: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleWatched) {
                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isWatched ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canMark)
            .help(canMark ? (isWatched ? "Отметить как не просмотренную" : "Отметить как просмотренную") : "Войди в аккаунт, чтобы отмечать серии")

            Button(action: onPlay) {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.name ?? "Серия \(episode.position + 1)")
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let url = episode.url, !url.isEmpty {
                            Text(host(of: url))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func host(of url: String) -> String {
        URL(string: url)?.host ?? url
    }
}

struct EpisodePlayerSheet: View {
    let releaseTitle: String?
    let isWatched: (Episode) -> Bool
    let onMarkWatched: (Episode) async -> Void

    @State private var session: EpisodePlaybackSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    fileprivate init(
        session: EpisodePlaybackSession,
        releaseTitle: String?,
        isWatched: @escaping (Episode) -> Bool,
        onMarkWatched: @escaping (Episode) async -> Void
    ) {
        self._session = State(initialValue: session)
        self.releaseTitle = releaseTitle
        self.isWatched = isWatched
        self.onMarkWatched = onMarkWatched
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentEpisode.name ?? "Серия \(currentEpisode.position + 1)")
                        .font(.headline)
                    if let title = releaseTitle {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if session.episodes.count > 1 {
                        Text("\(session.currentIndex + 1) из \(session.episodes.count)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                playbackControls
                if let url = currentEpisode.resolvedURL {
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .help("Открыть в Safari")
                }
                Button("Закрыть") {
                    markCurrentWatched()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            if let url = currentEpisode.resolvedURL {
                WebView(url: url)
                    .frame(minWidth: 800, minHeight: 480)
            } else {
                Text("Нет ссылки на плеер")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 600, minHeight: 300)
            }
        }
        .frame(minWidth: 800, minHeight: 540)
    }

    private var currentEpisode: Episode {
        session.currentEpisode
    }

    private var nextUnwatchedIndex: Int? {
        session.firstLaterUnwatchedIndex(isWatched: isWatched)
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            Button {
                if let index = session.previousIndex {
                    navigate(to: index)
                }
            } label: {
                Label("Предыдущая", systemImage: "chevron.left")
            }
            .disabled(session.previousIndex == nil)
            .help("Открыть предыдущую серию")

            Button {
                if let index = nextUnwatchedIndex {
                    navigate(to: index)
                }
            } label: {
                Label("Следующая непросмотренная", systemImage: "forward.end")
            }
            .disabled(nextUnwatchedIndex == nil)
            .help("Открыть следующую непросмотренную серию")

            Button {
                if let index = session.nextIndex {
                    navigate(to: index)
                }
            } label: {
                Label("Следующая", systemImage: "chevron.right")
            }
            .disabled(session.nextIndex == nil)
            .help("Открыть следующую серию")
        }
        .controlSize(.small)
    }

    private func navigate(to index: Int) {
        markCurrentWatched()
        session.currentIndex = index
    }

    private func markCurrentWatched() {
        let episode = currentEpisode
        Task {
            await onMarkWatched(episode)
        }
    }
}

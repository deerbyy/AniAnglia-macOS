import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var watching: [Release] = []
    @Published var recommendations: [Release] = []
    @Published var discussing: [Release] = []
    @Published var commentsWeek: [ReleaseComment] = []
    @Published var weekCollections: [AnixartCollection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(api: AnixartAPI) async {
        isLoading = true
        do {
            let watchingResp = try await api.discoverWatching(page: 0)
            self.watching = watchingResp.items
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        if let discussingResp = try? await api.discoverDiscussing() {
            self.discussing = discussingResp.items
        } else {
            self.discussing = []
        }
        if let commentsResp = try? await api.discoverCommentsWeek() {
            self.commentsWeek = commentsResp.content
        } else {
            self.commentsWeek = []
        }
        if let collectionsResp = try? await api.discoverWeekCollections(page: 0) {
            self.weekCollections = collectionsResp.items
        } else {
            self.weekCollections = []
        }
        // Personal recommendations only when authed (don't fail the whole load if this fails).
        if api.auth.isAuthenticated {
            if let recs = try? await api.discoverRecommendations(page: 0).items {
                self.recommendations = recs
            }
        } else {
            self.recommendations = []
        }
        isLoading = false
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HomeViewModel()

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
                    if !vm.recommendations.isEmpty {
                        section(title: "Рекомендации", releases: vm.recommendations)
                    }
                    if !vm.discussing.isEmpty {
                        section(title: "Обсуждают", releases: vm.discussing)
                    }
                    section(title: "Сейчас смотрят", releases: vm.watching)
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

    private func section(title: String, releases: [Release]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(releases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Комментарии недели")
                .font(.title3.bold())
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(vm.commentsWeek.prefix(6))) { comment in
                    if let release = comment.release {
                        NavigationLink(value: release) {
                            WeeklyCommentRow(comment: comment)
                        }
                        .buttonStyle(.plain)
                    } else {
                        WeeklyCommentRow(comment: comment)
                    }
                }
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Коллекции недели")
                    .font(.title3.bold())
                Spacer()
                Button("Все") {
                    appState.selectedSidebar = .collections
                }
                .buttonStyle(.borderless)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(vm.weekCollections) { collection in
                        NavigationLink(value: CollectionRoute(collection)) {
                            CollectionCard(collection: collection, style: .compact)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct WeeklyCommentRow: View {
    let comment: ReleaseComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(url: comment.profile?.avatarURL, contentMode: .fill) {
                Circle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.profile?.displayName ?? "—")
                        .font(.callout.bold())
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
                if let originTitle = comment.originTitle {
                    Text(originTitle)
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }
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

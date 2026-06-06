import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var releases: [Release] = []
    @Published var page = 0
    @Published var totalPages: Int?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    func reload(api: AnixartAPI) async {
        isLoading = true
        page = 0
        errorMessage = nil
        do {
            let resp = try await api.watchHistory(page: 0)
            releases = resp.items
            totalPages = resp.totalPageCount
        } catch {
            errorMessage = error.localizedDescription
            releases = []
        }
        isLoading = false
    }

    func loadMore(api: AnixartAPI) async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let next = page + 1
        do {
            let resp = try await api.watchHistory(page: next)
            releases = deduplicated(releases + resp.items)
            page = next
            totalPages = resp.totalPageCount
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canLoadMore: Bool {
        guard !isLoading, !isLoadingMore else { return false }
        guard let total = totalPages else { return false }
        return page + 1 < total
    }

    func loadMoreIfNeeded(current release: Release, api: AnixartAPI) async {
        guard release.id == releases.last?.id else { return }
        await loadMore(api: api)
    }

    private func deduplicated(_ releases: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return releases.filter { release in
            seen.insert(release.id).inserted
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HistoryViewModel()

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !appState.auth.isAuthenticated {
                    ContentUnavailable(systemImage: "person.crop.circle.badge.xmark",
                                       title: "Нужен вход",
                                       message: "Войди в аккаунт Anixart, чтобы видеть историю просмотров. Кнопка «Войти» сверху справа.")
                } else if let error = vm.errorMessage, vm.releases.isEmpty {
                    ErrorState(message: error) {
                        Task { await vm.reload(api: appState.api) }
                    }
                } else if vm.releases.isEmpty && !vm.isLoading {
                    ContentUnavailable(systemImage: "clock",
                                       title: "История пуста",
                                       message: "Когда отметишь хотя бы одну серию просмотренной, релиз появится здесь.")
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(vm.releases) { release in
                            NavigationLink(value: release) {
                                ReleaseCard(release: release)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await vm.loadMoreIfNeeded(current: release, api: appState.api) }
                            }
                        }
                    }
                    if vm.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    } else if vm.canLoadMore {
                        Button {
                            Task { await vm.loadMore(api: appState.api) }
                        } label: {
                            HStack {
                                Text("Показать ещё")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("История")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.reload(api: appState.api) }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task(id: appState.auth.profileId) {
            if appState.auth.isAuthenticated && vm.releases.isEmpty {
                await vm.reload(api: appState.api)
            }
        }
    }
}

struct ContentUnavailable: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

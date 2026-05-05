import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var interesting: [ReleaseSummary] = []
    @Published var watching: [ReleaseSummary] = []
    @Published var random: [ReleaseSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var hasLoaded = false

    func load(api: AnixartAPIClient, force: Bool = false) async {
        guard force || !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        errorMessage = nil
        do {
            async let interesting = api.interesting()
            async let watchingPage = api.watching(page: 0)
            let random = try await loadRandom(api: api)
            self.interesting = try await interesting
            self.watching = try await watchingPage.releases
            self.random = random
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadRandom(api: AnixartAPIClient) async throws -> [ReleaseSummary] {
        var items: [ReleaseSummary] = []
        for _ in 0..<8 {
            if let release = try? await api.random(), !items.contains(where: { $0.id == release.id }) {
                items.append(release)
            }
        }
        return items
    }
}

struct HomeView: View {
    let onSelectRelease: (Int) -> Void

    @Environment(\.anixartAPI) private var api
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.interesting.isEmpty {
                LoadingStateView(title: "Загружаем каталог")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        ReleaseCarousel(title: "Интересное", releases: viewModel.interesting, onSelectRelease: onSelectRelease)
                        ReleaseCarousel(title: "Смотрят сейчас", releases: viewModel.watching, onSelectRelease: onSelectRelease)
                        ReleaseCarousel(title: "Случайные", releases: viewModel.random, onSelectRelease: onSelectRelease)
                    }
                    .padding(24)
                }
                .refreshable {
                    await viewModel.load(api: api, force: true)
                }
            }
        }
        .task {
            await viewModel.load(api: api)
        }
        .toolbar {
            Button {
                Task { await viewModel.load(api: api, force: true) }
            } label: {
                Label("Обновить", systemImage: "arrow.clockwise")
            }
        }
    }
}

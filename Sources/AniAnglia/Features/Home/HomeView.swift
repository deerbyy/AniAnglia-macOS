import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var interesting: [Release] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(api: AnixartAPI) async {
        isLoading = true
        defer { isLoading = false }
        do {
            interesting = try await api.discoverInteresting()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if vm.isLoading && vm.interesting.isEmpty {
                    ProgressView("Загрузка…")
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage, vm.interesting.isEmpty {
                    ErrorState(message: error) {
                        Task { await vm.load(api: appState.api) }
                    }
                } else {
                    section(title: "Интересное", releases: vm.interesting)
                }
            }
            .padding(24)
        }
        .navigationTitle("Главная")
        .navigationDestination(for: Release.self) { release in
            ReleaseDetailView(releaseId: release.id, prefetched: release)
        }
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

import SwiftUI

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var releases: [Release] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var category: Int = 2 // Watching by default

    func load(api: AnixartAPI) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.bookmarks(category: category, page: 0)
            releases = resp.items
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            // Keep old releases on transient error? Clear only on auth error
            if (error as? APIError)?.localizedDescription.contains("Не авторизован") == true {
                releases = []
            }
        }
    }
}

struct BookmarksView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = BookmarksViewModel()

    private let categories: [(Int, String)] = [
        (2, "Смотрю"), (1, "В планах"), (3, "Просмотрено"), (4, "Отложено"), (5, "Брошено")
    ]

    var body: some View {
        VStack(spacing: 0) {
            categoryPicker
                .padding(.horizontal)
                .padding(.top, 12)
            content
        }
        .navigationTitle("Закладки")
        .task(id: vm.category) {
            await vm.load(api: appState.api)
        }
        .onAppear {
            applyPendingCategoryIfNeeded()
        }
        .onChange(of: appState.pendingBookmarkCategory) { newValue in
            if newValue != nil {
                applyPendingCategoryIfNeeded()
            }
        }
        // Reload when auth state changes (login/logout) – AppState forwards objectWillChange
        .task(id: appState.auth.isAuthenticated) {
            if appState.auth.isAuthenticated {
                await vm.load(api: appState.api)
            } else {
                vm.releases = []
            }
        }
    }

    private func applyPendingCategoryIfNeeded() {
        if let pending = appState.pendingBookmarkCategory {
            vm.category = pending
            appState.pendingBookmarkCategory = nil
        }
    }

    private var categoryPicker: some View {
        Picker("", selection: $vm.category) {
            ForEach(categories, id: \.0) { (id, title) in
                Text(title).tag(id)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        if !appState.auth.isAuthenticated {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Нужен вход в аккаунт")
                    .font(.headline)
                Text("Закладки доступны только авторизованным пользователям. Войди на вкладке «Профиль».")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.isLoading && vm.releases.isEmpty {
            ProgressView().padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage, vm.releases.isEmpty {
            ErrorState(message: error) {
                Task { await vm.load(api: appState.api) }
            }
        } else if vm.releases.isEmpty {
            Text("Список пуст")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(vm.releases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

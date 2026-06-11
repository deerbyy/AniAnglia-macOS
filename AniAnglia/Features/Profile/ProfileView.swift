import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(authStore: AuthStore, api: AnixartAPIClient) async {
        guard let session = authStore.currentSession else {
            profile = nil
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            profile = try await api.profile(profileID: session.profileId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ProfileView: View {
    let onSelectRelease: (Int) -> Void

    @Environment(\.anixartAPI) private var api
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        Group {
            if !authStore.isAuthenticated {
                LoginView()
            } else if viewModel.isLoading && viewModel.profile == nil {
                LoadingStateView(title: "Загружаем профиль")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        if let profile = viewModel.profile ?? authStore.currentSession?.profile {
                            HStack(alignment: .center, spacing: 18) {
                                CachedRemoteImage(urlString: profile.avatar, contentMode: .fill)
                                    .frame(width: 92, height: 92)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(profile.displayName)
                                        .font(.largeTitle.weight(.semibold))
                                    Text(profile.status.nonEmpty ?? "Статус не указан")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 14) {
                                metric("Закладки", profile.favoritesCount)
                                metric("Просмотрено", profile.watchedCount)
                                metric("ID", profile.id)
                            }
                        }

                        Button(role: .destructive) {
                            authStore.signOut()
                        } label: {
                            Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 760, alignment: .leading)
                }
            }
        }
        .task(id: authStore.currentSession?.profileId) {
            await viewModel.load(authStore: authStore, api: api)
        }
        .toolbar {
            Button {
                Task { await viewModel.load(authStore: authStore, api: api) }
            } label: {
                Label("Обновить", systemImage: "arrow.clockwise")
            }
            .disabled(!authStore.isAuthenticated)
        }
    }

    private func metric(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value?.compactText ?? "0")
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 130, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

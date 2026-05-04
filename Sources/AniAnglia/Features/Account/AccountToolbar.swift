import SwiftUI

/// Toolbar control that shows a "Sign in" button when logged out
/// and a profile menu (avatar + login) when authenticated.
struct AccountToolbar: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var auth: AuthStore
    @State private var showingLogin = false
    @State private var miniProfile: Profile?

    var body: some View {
        Group {
            if auth.isAuthenticated {
                authedMenu
            } else {
                Button {
                    showingLogin = true
                } label: {
                    Label("Войти", systemImage: "person.crop.circle.badge.plus")
                }
                .help("Войти в аккаунт Anixart")
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginSheet()
                .environmentObject(appState)
        }
    }

    private var authedMenu: some View {
        Menu {
            if let profile = miniProfile {
                Text(profile.login ?? "Аккаунт")
            }
            Button("Открыть профиль") {
                appState.selectedSidebar = .profile
            }
            Divider()
            Button("Выйти", role: .destructive) {
                appState.auth.signOut()
                miniProfile = nil
            }
        } label: {
            HStack(spacing: 6) {
                if let url = miniProfile?.avatarURL {
                    RemoteImage(url: url, contentMode: .fill) {
                        Circle().fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 18))
                }
                Text(miniProfile?.login ?? "Аккаунт")
                    .lineLimit(1)
            }
        }
        .task(id: auth.profileId) {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        guard let id = auth.profileId else {
            miniProfile = nil
            return
        }
        miniProfile = try? await appState.api.profile(id: id)
    }
}

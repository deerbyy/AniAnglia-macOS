import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var login = ""
    @Published var password = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    func loadCurrentProfile(api: AnixartAPI, auth: AuthStore) async {
        guard let id = auth.profileId else { return }
        do {
            profile = try await api.profile(id: id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(api: AnixartAPI, auth: AuthStore) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let resp = try await api.signIn(login: login, password: password)
            guard resp.code == 0, let token = resp.profileToken?.token, let pid = resp.profile?.id else {
                errorMessage = resp.message ?? "Не удалось войти (code=\(resp.code))"
                return
            }
            auth.setCredentials(token: token, profileId: pid)
            profile = resp.profile
            errorMessage = nil
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        Group {
            if appState.auth.isAuthenticated {
                authenticated
            } else {
                signInForm
            }
        }
        .navigationTitle("Профиль")
        .task {
            await vm.loadCurrentProfile(api: appState.api, auth: appState.auth)
        }
    }

    @ViewBuilder
    private var authenticated: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let profile = vm.profile {
                    RemoteImage(url: profile.avatarURL, contentMode: .fill) {
                        Circle().fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())

                    Text(profile.login ?? "—")
                        .font(.title2.bold())

                    if let status = profile.status, !status.isEmpty {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    statsGrid(for: profile)
                } else {
                    ProgressView()
                }

                Button("Выйти из аккаунта") {
                    appState.auth.signOut()
                    vm.profile = nil
                }
                .padding(.top, 12)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    private func statsGrid(for profile: Profile) -> some View {
        let stats: [(String, Int?)] = [
            ("Смотрю", profile.watchingReleasesCount),
            ("В планах", profile.plannedReleasesCount),
            ("Просмотрено", profile.watchedReleasesCount),
            ("Отложено", profile.holdOnReleasesCount),
            ("Брошено", profile.abandonedReleasesCount)
        ]
        return HStack(spacing: 12) {
            ForEach(stats, id: \.0) { (title, value) in
                VStack(spacing: 4) {
                    Text("\(value ?? 0)")
                        .font(.title3.bold())
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 12)
    }

    private var signInForm: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Вход в Anixart")
                .font(.title2.bold())

            VStack(spacing: 10) {
                TextField("Логин или e-mail", text: $vm.login)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                SecureField("Пароль", text: $vm.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await vm.signIn(api: appState.api, auth: appState.auth) }
            } label: {
                if vm.isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Войти")
                        .frame(width: 80)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.login.isEmpty || vm.password.isEmpty || vm.isWorking)

            Text("Анонимный режим работает без входа — ты можешь смотреть каталог, поиск и страницы релизов без авторизации, но закладки и комменты будут недоступны.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .padding(.top, 16)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var login = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !isLoading
    }

    func submit(api: AnixartAPIClient, authStore: AuthStore) async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await api.signIn(login: login, password: password)
            authStore.save(session: session)
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct LoginView: View {
    @Environment(\.anixartAPI) private var api
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Вход в Anixart")
                .font(.largeTitle.weight(.semibold))

            Text("Можно пользоваться каталогом анонимно. Вход нужен для профиля, закладок и статусов просмотра.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = viewModel.errorMessage ?? authStore.authError {
                ErrorBanner(message: errorMessage)
            }

            TextField("Логин или email", text: $viewModel.login)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            SecureField("Пароль", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
                .onSubmit {
                    Task { await viewModel.submit(api: api, authStore: authStore) }
                }

            HStack {
                Button {
                    Task { await viewModel.submit(api: api, authStore: authStore) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Label("Войти", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canSubmit)

                Text("Анонимный режим включен по умолчанию.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct LoginRequiredView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text("Откройте раздел «Профиль» и войдите логином и паролем Anixart.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

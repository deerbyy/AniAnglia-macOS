import SwiftUI

@MainActor
final class LoginSheetViewModel: ObservableObject {
    @Published var login: String = ""
    @Published var password: String = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    func signIn(api: AnixartAPI, auth: AuthStore) async -> Bool {
        guard !login.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            errorMessage = "Введи логин и пароль"
            return false
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let resp = try await api.signIn(login: login, password: password)
            if resp.code == 0,
               let token = resp.profileToken?.token,
               let pid = resp.profile?.id {
                auth.setCredentials(token: token, profileId: pid)
                password = ""
                return true
            }
            errorMessage = readableError(for: resp.code, fallback: resp.message)
            return false
        } catch let APIError.server(code, message) {
            errorMessage = readableError(for: code, fallback: message)
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func readableError(for code: Int, fallback: String?) -> String {
        switch code {
        case 2: return "Неверный логин или пароль"
        case 4: return "Аккаунт заблокирован"
        case 5: return "Включена двухфакторная авторизация — войди через сайт"
        default: return fallback ?? "Anixart отклонил вход (code=\(code))"
        }
    }
}

struct LoginSheet: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = LoginSheetViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Вход в Anixart").font(.title2.bold())
                    Text("Логин/e-mail и пароль от api.anixart.tv")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                TextField("Логин или e-mail", text: $vm.login)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                SecureField("Пароль", text: $vm.password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submit() }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Link("Забыл пароль?", destination: URL(string: "https://anixart.tv")!)
                    .font(.caption)
                Spacer()
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    submit()
                } label: {
                    if vm.isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Войти").bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(vm.isWorking)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func submit() {
        Task {
            let ok = await vm.signIn(api: appState.api, auth: appState.auth)
            if ok { dismiss() }
        }
    }
}

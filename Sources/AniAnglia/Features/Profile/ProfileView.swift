import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var login = ""
    @Published var password = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    /// Mapping: bookmark category id -> first synced releases (preview).
    @Published var previews: [Int: [Release]] = [:]
    @Published var previewsLoading = false

    func loadCurrentProfile(api: AnixartAPI, auth: AuthStore) async {
        guard let id = auth.profileId else { return }
        do {
            profile = try await api.profile(id: id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadBookmarkPreviews(api: AnixartAPI, syncStore: BookmarkSyncStore) async {
        previewsLoading = true
        defer { previewsLoading = false }
        await syncStore.syncAll(api: api)
        for category in BookmarkCategory.displayOrder {
            previews[category.rawValue] = Array(syncStore.releases(for: category).prefix(8))
        }
    }

    func signIn(api: AnixartAPI, auth: AuthStore) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let resp = try await api.signIn(login: login, password: password)
            guard resp.code == 0, let token = resp.profileToken?.token, let pid = resp.profileId ?? resp.profileToken?.id ?? resp.profile?.id else {
                errorMessage = readableSignInError(code: resp.code, fallback: resp.message)
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

    private func readableSignInError(code: Int, fallback: String?) -> String {
        switch code {
        case 2: return "Аккаунт не подтверждён по e-mail"
        case 3: return "Неверный логин или пароль"
        case 4: return "Аккаунт заблокирован"
        case 5: return "Включена двухфакторная авторизация — войди через сайт"
        default: return fallback ?? "Не удалось войти (code=\(code))"
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
        .task(id: appState.auth.profileId) {
            await vm.loadCurrentProfile(api: appState.api, auth: appState.auth)
            if appState.auth.isAuthenticated {
                await vm.loadBookmarkPreviews(api: appState.api, syncStore: appState.bookmarkSync)
            }
        }
    }

    @ViewBuilder
    private var authenticated: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader
                if let profile = vm.profile {
                    statsGrid(for: profile)
                    accountDetails(for: profile)
                }
                Divider()
                bookmarkSections
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var profileHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            RemoteImage(url: vm.profile?.avatarURL, contentMode: .fill) {
                Circle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 110, height: 110)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.profile?.displayName ?? "—")
                    .font(.system(size: 26, weight: .bold))
                HStack(spacing: 8) {
                    if vm.profile?.isOnline == true {
                        Label("Онлайн", systemImage: "circle.fill")
                            .foregroundStyle(.green)
                    }
                    if vm.profile?.isVerified == true {
                        Label("Верифицирован", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                    }
                    if vm.profile?.isSponsor == true {
                        Label("Sponsor", systemImage: "star.circle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.caption)
                if let status = vm.profile?.status, !status.isEmpty {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let registered = registerDateText {
                    Text(registered)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(spacing: 8) {
                Button {
                    Task {
                        await vm.loadCurrentProfile(api: appState.api, auth: appState.auth)
                        await vm.loadBookmarkPreviews(api: appState.api, syncStore: appState.bookmarkSync)
                    }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    appState.auth.signOut()
                    appState.bookmarkSync.clear()
                    vm.profile = nil
                    vm.previews = [:]
                } label: {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }

    private var registerDateText: String? {
        guard let ts = vm.profile?.registerDate, ts > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .long
        f.timeStyle = .none
        return "С \(f.string(from: date))"
    }

    private func statsGrid(for profile: Profile) -> some View {
        let stats: [(BookmarkCategory, Int?)] = [
            (.watching, profile.watchingReleasesCount),
            (.planned, profile.plannedReleasesCount),
            (.watched, profile.watchedReleasesCount),
            (.onHold, profile.holdOnReleasesCount),
            (.dropped, profile.abandonedReleasesCount)
        ]
        return HStack(spacing: 12) {
            ForEach(stats, id: \.0) { (category, value) in
                Button {
                    appState.selectSidebar(.bookmarks, bookmarkCategory: category.rawValue)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(value ?? appState.bookmarkSync.count(for: category))")
                            .font(.title3.bold().monospacedDigit())
                        Text(category.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .help("Открыть «\(category.title)»")
            }
        }
    }

    private func accountDetails(for profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if profile.isStatsHidden == true || profile.isCountsHidden == true {
                Label("Часть статистики скрыта настройками приватности Anixart.", systemImage: "eye.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
                accountMetric("Избранное", profile.favoriteCount ?? appState.bookmarkSync.favoritesCount, "star")
                accountMetric("Эпизоды", profile.watchedEpisodeCount, "play.rectangle")
                accountMetric("Комментарии", profile.commentCount, "text.bubble")
                accountMetric("Коллекции", profile.collectionCount, "rectangle.stack")
                accountMetric("Видео", profile.videoCount, "film")
                accountMetric("Друзья", profile.friendCount, "person.2")
                accountMetric("Рейтинг", profile.ratingScore, "chart.line.uptrend.xyaxis")
                if let watchedTime = profile.watchedTimeText {
                    accountMetric("Время просмотра", watchedTime, "clock")
                }
            }

            if !profile.socialLinks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Соцсети")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.socialLinks, id: \.title) { item in
                                Text("\(item.title): \(item.value)")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private func accountMetric(_ title: String, _ value: Int?, _ icon: String) -> some View {
        accountMetric(title, value.map(String.init), icon)
    }

    private func accountMetric(_ title: String, _ value: String?, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value ?? "—")
                    .font(.headline.monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var bookmarkSections: some View {
        ProfileBookmarkSections(
            appState: appState,
            syncStore: appState.bookmarkSync,
            isLoading: vm.previewsLoading
        )
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
                    .onSubmit {
                        Task { await vm.signIn(api: appState.api, auth: appState.auth) }
                    }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await vm.signIn(api: appState.api, auth: appState.auth)
                    if appState.auth.isAuthenticated {
                        await vm.loadCurrentProfile(api: appState.api, auth: appState.auth)
                        await vm.loadBookmarkPreviews(api: appState.api, syncStore: appState.bookmarkSync)
                    }
                }
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

            Text("Анонимный режим работает без входа — можно смотреть каталог, поиск и страницы релизов. Закладки, история, комменты и оценки требуют авторизации.")
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

private struct ProfileBookmarkSections: View {
    @ObservedObject var appState: AppState
    @ObservedObject var syncStore: BookmarkSyncStore
    let isLoading: Bool

    var body: some View {
        let favorites = Array(syncStore.favoriteReleases.prefix(8))
        if !favorites.isEmpty || isLoading {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(Color.yellow).frame(width: 10, height: 10)
                    Text("Избранное").font(.title3.bold())
                    Spacer()
                    Button("Все →") {
                        appState.selectSidebar(.bookmarks)
                    }
                    .buttonStyle(.borderless)
                }
                if favorites.isEmpty {
                    Text("Список пуст")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(favorites) { release in
                                NavigationLink(value: release) {
                                    ReleaseCard(release: release)
                                        .frame(width: 160)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }

        ForEach(BookmarkCategory.displayOrder) { category in
            let releases = Array(syncStore.releases(for: category).prefix(8))
            if !releases.isEmpty || isLoading {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle().fill(category.color).frame(width: 10, height: 10)
                        Text(category.title).font(.title3.bold())
                        Spacer()
                        Button("Все →") {
                            appState.selectSidebar(.bookmarks, bookmarkCategory: category.rawValue)
                        }
                        .buttonStyle(.borderless)
                    }
                    if releases.isEmpty {
                        Text("Список пуст")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(releases) { release in
                                    NavigationLink(value: release) {
                                        ReleaseCard(release: release)
                                            .frame(width: 160)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                }
            }
        }
    }
}

private extension BookmarkCategory {
    var color: Color {
        switch self {
        case .planned: return .yellow
        case .watching: return .indigo
        case .watched: return .green
        case .onHold: return .purple
        case .dropped: return .red
        }
    }
}

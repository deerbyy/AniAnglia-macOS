import SwiftUI

@MainActor
final class ProfileFriendsViewModel: ObservableObject {
    @Published var friends: [Profile] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    let route: ProfileFriendsRoute

    private var page = 0
    private var totalPageCount: Int?
    private var reachedEnd = false

    init(route: ProfileFriendsRoute) {
        self.route = route
    }

    var filteredFriends: [Profile] {
        friends.filter { $0.matchesProfileQuery(searchQuery) }
    }

    var hasSearchQuery: Bool {
        !searchQuery.normalizedLibrarySearchQuery.isEmpty
    }

    var canLoadMore: Bool {
        !isLoading && !isLoadingMore && !reachedEnd
    }

    var countText: String {
        if hasSearchQuery {
            return "\(filteredFriends.count) из \(friends.count)"
        }
        if let totalCount = route.totalCount, totalCount > friends.count {
            return "\(friends.count) из \(totalCount)"
        }
        return "\(friends.count)"
    }

    func reload(api: AnixartAPI) async {
        isLoading = true
        errorMessage = nil
        page = 0
        totalPageCount = nil
        reachedEnd = false
        defer { isLoading = false }

        do {
            let response = try await api.profileFriends(profileId: route.profileId, page: 0)
            let incoming = response.items
            friends = deduplicated(incoming)
            totalPageCount = response.totalPageCount
            reachedEnd = isLastPage(currentPage: 0, pageItems: incoming)
            page = 1
        } catch {
            friends = []
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(api: AnixartAPI) async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await api.profileFriends(profileId: route.profileId, page: page)
            let incoming = response.items
            friends = deduplicated(friends + incoming)
            totalPageCount = response.totalPageCount
            reachedEnd = isLastPage(currentPage: page, pageItems: incoming)
            page += 1
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current profile: Profile, api: AnixartAPI) async {
        guard profile.id == filteredFriends.last?.id else { return }
        await loadMore(api: api)
    }

    private func isLastPage(currentPage: Int, pageItems: [Profile]) -> Bool {
        if let totalPageCount {
            return currentPage + 1 >= totalPageCount
        }
        return pageItems.isEmpty
    }

    private func deduplicated(_ input: [Profile]) -> [Profile] {
        var seen = Set<Int64>()
        return input.filter { profile in
            seen.insert(profile.id).inserted
        }
    }
}

struct ProfileFriendsView: View {
    let route: ProfileFriendsRoute

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: ProfileFriendsViewModel

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 14)]

    init(route: ProfileFriendsRoute) {
        self.route = route
        _vm = StateObject(wrappedValue: ProfileFriendsViewModel(route: route))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                searchField

                if let error = vm.errorMessage, vm.friends.isEmpty {
                    ErrorState(message: error) {
                        Task { await vm.reload(api: appState.api) }
                    }
                } else if vm.friends.isEmpty && vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if vm.friends.isEmpty {
                    ContentUnavailable(
                        systemImage: "person.2.slash",
                        title: "Друзей нет",
                        message: "Список может быть пустым или скрытым настройками приватности Anixart."
                    )
                } else if vm.filteredFriends.isEmpty {
                    ContentUnavailable(
                        systemImage: "magnifyingglass",
                        title: "Ничего не найдено",
                        message: "Попробуй изменить запрос или догрузить список ниже."
                    )
                    paginationFooter
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(vm.filteredFriends) { profile in
                            NavigationLink(value: ProfileRoute(profile)) {
                                ProfileFriendListCard(profile: profile)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await vm.loadMoreIfNeeded(current: profile, api: appState.api) }
                            }
                        }
                    }
                    paginationFooter
                }
            }
            .padding(20)
        }
        .navigationTitle("Друзья")
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
        .task(id: route.profileId) {
            if vm.friends.isEmpty {
                await vm.reload(api: appState.api)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Друзья")
                    .font(.title2.bold())
                Text(profileSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(vm.countText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск по друзьям", text: $vm.searchQuery)
                .textFieldStyle(.plain)
            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Очистить поиск")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if vm.isLoadingMore {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else if vm.canLoadMore {
            Button {
                Task { await vm.loadMore(api: appState.api) }
            } label: {
                Text("Показать ещё")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    private var profileSubtitle: String {
        if let profileName = route.profileName, !profileName.isEmpty {
            return "Профиль: \(profileName)"
        }
        return "Профиль #\(route.profileId)"
    }
}

private struct ProfileFriendListCard: View {
    let profile: Profile

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RemoteImage(url: profile.avatarURL, contentMode: .fill) {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                }
                .frame(width: 54, height: 54)
                .clipShape(Circle())

                if profile.isOnline == true {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if profile.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if profile.isSponsor == true {
                        Image(systemName: "star.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(activityText)
                    .font(.caption2)
                    .foregroundStyle(profile.isOnline == true ? Color.green : Color.secondary)
                    .lineLimit(1)

                if let status = profile.status, !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var activityText: String {
        if profile.isOnline == true {
            return "Онлайн"
        }
        guard let timestamp = profile.lastActivityTime, timestamp > 0 else {
            return "Оффлайн"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(timeIntervalSince1970: TimeInterval(timestamp)), relativeTo: Date())
    }
}

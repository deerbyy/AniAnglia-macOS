import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var watching: [Release] = []
    @Published var recommendations: [Release] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Адаптация AniDesk Home.tsx: 5 вкладок + пагинация
    @Published var selectedTab: Int = 0 // 0=Последние,1=Онгоинги,2=Анонсы,3=Завершенные,4=Фильмы
    @Published var filtered: [Release] = []
    @Published var filterPage = 0
    @Published var filterTotalPages: Int?
    @Published var isLoadingFilter = false
    @Published var filterError: String?

    func load(api: AnixartAPI) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let watchingResp = try await api.discoverWatching(page: 0)
            self.watching = watchingResp.items
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            watching = []
        }
        if api.auth.isAuthenticated {
            do {
                let recs = try await api.discoverRecommendations(page: 0)
                self.recommendations = recs.items
            } catch {
                self.recommendations = []
            }
        } else {
            self.recommendations = []
        }
        // Грузим фильтрованную ленту для выбранной вкладки
        await loadFiltered(api: api, reset: true)
    }

    func loadFiltered(api: AnixartAPI, reset: Bool = false) async {
        if isLoadingFilter { return }
        if reset {
            filtered = []
            filterPage = 0
            filterTotalPages = nil
            filterError = nil
        }
        guard canLoadMoreFilter else { return }
        isLoadingFilter = true
        defer { isLoadingFilter = false }
        let page = reset ? 0 : filterPage + 1
        let args = filterArgs(for: selectedTab)
        do {
            let resp = try await api.filter(
                page: page,
                sort: args.sort,
                category: args.category,
                status: args.status
            )
            if reset {
                filtered = resp.items
                filterPage = 0
            } else {
                if resp.items.isEmpty {
                    filterTotalPages = page
                } else {
                    filtered.append(contentsOf: resp.items)
                    filterPage = page
                }
            }
            filterTotalPages = resp.totalPageCount
            filterError = nil
        } catch {
            filterError = error.localizedDescription
        }
    }

    func selectTab(_ tab: Int, api: AnixartAPI) async {
        guard tab != selectedTab else { return }
        selectedTab = tab
        await loadFiltered(api: api, reset: true)
    }

    var canLoadMoreFilter: Bool {
        if filtered.isEmpty { return true }
        if let total = filterTotalPages { return filterPage + 1 < total }
        return true
    }

    private func filterArgs(for tab: Int) -> (sort: Int, category: Int?, status: Int?) {
        // Маппинг AniDesk Home.tsx -> наш API (sort:0=обновление, status 1=Вышел,2=Анонс,3=Онгоинг)
        switch tab {
        case 0: return (sort: 0, category: nil, status: nil) // Последние
        case 1: return (sort: 0, category: nil, status: 3) // Онгоинги (AniDesk status 2 -> наш 3)
        case 2: return (sort: 0, category: nil, status: 2) // Анонсы (AniDesk 3 -> наш 2)
        case 3: return (sort: 0, category: nil, status: 1) // Завершенные
        case 4: return (sort: 0, category: 2, status: nil) // Фильмы
        default: return (sort: 0, category: nil, status: nil)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HomeViewModel()

    private let tabs = ["Последние", "Онгоинги", "Анонсы", "Завершенные", "Фильмы"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if vm.isLoading && vm.watching.isEmpty && vm.filtered.isEmpty {
                    ProgressView("Загрузка…")
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage, vm.watching.isEmpty && vm.filtered.isEmpty {
                    ErrorState(message: error) {
                        Task { await vm.load(api: appState.api) }
                    }
                } else {
                    if !vm.recommendations.isEmpty {
                        section(title: "Рекомендации", releases: vm.recommendations)
                    }
                    section(title: "Сейчас смотрят", releases: vm.watching)

                    // MARK: - Фильтрованная лента как в AniDesk Home
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Каталог").font(.title3.bold())
                            Spacer()
                            // Скрытый хелпер для отладки: показывает текущий фильтр
                            Text(AniDeskUtils.seasons[1] ?? "").hidden()
                        }
                        Picker("", selection: Binding(
                            get: { vm.selectedTab },
                            set: { newVal in Task { await vm.selectTab(newVal, api: appState.api) } }
                        )) {
                            ForEach(0..<tabs.count, id: \.self) { i in Text(tabs[i]).tag(i) }
                        }
                        .pickerStyle(.segmented)

                        if vm.isLoadingFilter && vm.filtered.isEmpty {
                            ProgressView().padding(.vertical, 20).frame(maxWidth: .infinity)
                        } else if let err = vm.filterError, vm.filtered.isEmpty {
                            ErrorState(message: err) { Task { await vm.loadFiltered(api: appState.api, reset: true) } }
                        } else if vm.filtered.isEmpty {
                            Text("Ничего не найдено").foregroundStyle(.secondary).padding(.vertical, 20).frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 20) {
                                ForEach(vm.filtered) { release in
                                    NavigationLink(value: release) {
                                        ReleaseCard(release: release)
                                    }.buttonStyle(.plain)
                                }
                            }
                            if vm.canLoadMoreFilter {
                                Button {
                                    Task { await vm.loadFiltered(api: appState.api) }
                                } label: {
                                    if vm.isLoadingFilter { ProgressView().controlSize(.small) } else { Text("Показать ещё") }
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.isLoadingFilter)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Главная")
        .task { await vm.load(api: appState.api) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await vm.load(api: appState.api) } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Обновить").disabled(vm.isLoading || vm.isLoadingFilter)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AniAnglia").font(.system(size: 28, weight: .bold))
                Text("Неофициальный клиент Anixart для macOS").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func section(title: String, releases: [Release]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(releases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }.buttonStyle(.plain)
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
            Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundStyle(.orange)
            Text("Не удалось загрузить").font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Повторить", action: onRetry).buttonStyle(.borderedProminent)
        }.padding(40).frame(maxWidth: .infinity)
    }
}

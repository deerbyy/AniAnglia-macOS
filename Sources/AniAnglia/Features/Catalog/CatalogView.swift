import SwiftUI

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var releases: [Release] = []
    @Published var page = 0
    @Published var totalPages: Int?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    @Published var sort: Int = 3 // Popular
    @Published var category: Int? = nil
    @Published var status: Int? = nil
    @Published var startYear: Int? = nil
    @Published var endYear: Int? = nil
    @Published var genres: Set<String> = []
    @Published var excludeGenres: Bool = false

    var hasActiveFilters: Bool {
        category != nil
            || status != nil
            || startYear != nil
            || endYear != nil
            || !genres.isEmpty
            || excludeGenres
            || sort != 3
    }

    func resetFilters() {
        sort = 3
        category = nil
        status = nil
        startYear = nil
        endYear = nil
        genres = []
        excludeGenres = false
    }

    func applyPreset(_ preset: CatalogPreset) {
        resetFilters()
        sort = preset.sort
        category = preset.category
        status = preset.status
        startYear = preset.startYear
        endYear = preset.endYear
        genres = Set(preset.genres)
        excludeGenres = preset.excludeGenres
    }

    func reload(api: AnixartAPI) async {
        page = 0
        releases = []
        await loadMore(api: api)
    }

    func loadMore(api: AnixartAPI) async {
        guard canLoadMore() else { return }
        let requestPage = page
        if releases.isEmpty {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }
        do {
            let resp = try await api.filter(
                page: requestPage,
                sort: sort,
                category: category,
                status: status,
                startYear: startYear,
                endYear: endYear,
                genres: Array(genres),
                excludeGenres: excludeGenres
            )
            releases = deduplicated(releases + resp.items)
            page = requestPage + 1
            totalPages = resp.totalPageCount
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canLoadMore() -> Bool {
        guard !isLoading, !isLoadingMore else { return false }
        if releases.isEmpty && page == 0 && totalPages == nil { return true }
        if let total = totalPages, total > 0 { return page < total }
        return !releases.isEmpty
    }

    func loadMoreIfNeeded(current release: Release, api: AnixartAPI) async {
        guard release.id == releases.last?.id else { return }
        await loadMore(api: api)
    }

    private func deduplicated(_ releases: [Release]) -> [Release] {
        var seen = Set<Int64>()
        return releases.filter { release in
            seen.insert(release.id).inserted
        }
    }
}

struct CatalogPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let sort: Int
    let category: Int?
    let status: Int?
    let startYear: Int?
    let endYear: Int?
    let genres: [String]
    let excludeGenres: Bool

    static let displayOrder: [CatalogPreset] = [
        CatalogPreset(
            id: "ongoing-series",
            title: "Онгоинги",
            systemImage: "dot.radiowaves.left.and.right",
            sort: 3,
            category: 1,
            status: 3,
            startYear: nil,
            endYear: nil,
            genres: [],
            excludeGenres: false
        ),
        CatalogPreset(
            id: "movies",
            title: "Фильмы",
            systemImage: "film",
            sort: 3,
            category: 2,
            status: nil,
            startYear: nil,
            endYear: nil,
            genres: [],
            excludeGenres: false
        ),
        CatalogPreset(
            id: "recent-popular",
            title: "Популярное 2024+",
            systemImage: "chart.line.uptrend.xyaxis",
            sort: 3,
            category: nil,
            status: nil,
            startYear: 2024,
            endYear: nil,
            genres: [],
            excludeGenres: false
        ),
        CatalogPreset(
            id: "high-rated",
            title: "Высокая оценка",
            systemImage: "star.fill",
            sort: 1,
            category: nil,
            status: nil,
            startYear: nil,
            endYear: nil,
            genres: [],
            excludeGenres: false
        )
    ]
}

struct CatalogView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = CatalogViewModel()
    @State private var pendingReleaseIds: Set<Int64> = []

    private let sortOptions: [(Int, String)] = [
        (3, "По популярности"),
        (1, "По оценке"),
        (0, "По обновлению"),
        (2, "По году")
    ]
    private let categoryOptions: [(Int?, String)] = [
        (nil, "Все категории"),
        (1, "Сериал"),
        (2, "Фильм"),
        (3, "OVA"),
        (4, "ONA"),
        (5, "Спешл")
    ]
    private let statusOptions: [(Int?, String)] = [
        (nil, "Любой статус"),
        (1, "Вышел"),
        (2, "Анонс"),
        (3, "Онгоинг")
    ]
    private let yearOptions: [Int] = Array(stride(from: 2026, through: 1960, by: -1))

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                filtersBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            Divider()
            content
        }
        .navigationTitle("Каталог")
        .alert("Не удалось", isPresented: Binding(
            get: { appState.bookmarkSync.errorMessage != nil },
            set: { if !$0 { appState.bookmarkSync.errorMessage = nil } }
        ), actions: {
            Button("OK") { appState.bookmarkSync.errorMessage = nil }
        }, message: {
            Text(appState.bookmarkSync.errorMessage ?? "")
        })
        .task {
            if vm.releases.isEmpty {
                await vm.reload(api: appState.api)
            }
        }
    }

    private var filtersBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(CatalogPreset.displayOrder) { preset in
                    Button {
                        vm.applyPreset(preset)
                        Task { await vm.reload(api: appState.api) }
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Picker("Сортировка", selection: $vm.sort) {
                    ForEach(sortOptions, id: \.0) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)

                Picker("Категория", selection: $vm.category) {
                    ForEach(categoryOptions, id: \.1) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                Picker("Статус", selection: $vm.status) {
                    ForEach(statusOptions, id: \.1) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                Picker("С года", selection: $vm.startYear) {
                    Text("С").tag(Int?.none)
                    ForEach(yearOptions, id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)

                Picker("По год", selection: $vm.endYear) {
                    Text("По").tag(Int?.none)
                    ForEach(yearOptions, id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)

                GenresPickerButton(selected: $vm.genres, exclude: $vm.excludeGenres)

                Spacer()

                if vm.hasActiveFilters {
                    Button("Сбросить") {
                        vm.resetFilters()
                        Task { await vm.reload(api: appState.api) }
                    }
                    .buttonStyle(.bordered)
                }

                Button("Применить") {
                    Task { await vm.reload(api: appState.api) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }

            activeFiltersBar
        }
    }

    @ViewBuilder
    private var activeFiltersBar: some View {
        let chips = activeFilterChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var activeFilterChips: [String] {
        var chips: [String] = []
        if let sortTitle = sortOptions.first(where: { $0.0 == vm.sort })?.1, vm.sort != 3 {
            chips.append(sortTitle)
        }
        if let category = vm.category,
           let title = categoryOptions.first(where: { $0.0 == category })?.1 {
            chips.append(title)
        }
        if let status = vm.status,
           let title = statusOptions.first(where: { $0.0 == status })?.1 {
            chips.append(title)
        }
        if let startYear = vm.startYear {
            chips.append("с \(startYear)")
        }
        if let endYear = vm.endYear {
            chips.append("по \(endYear)")
        }
        if !vm.genres.isEmpty {
            let prefix = vm.excludeGenres ? "без" : "жанры"
            chips.append("\(prefix): \(vm.genres.sorted().joined(separator: ", "))")
        }
        return chips
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.releases.isEmpty {
            ProgressView().padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage, vm.releases.isEmpty {
            ErrorState(message: error) {
                Task { await vm.reload(api: appState.api) }
            }
        } else if vm.releases.isEmpty {
            Text("Ничего не найдено")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                HStack(spacing: 10) {
                    Text("\(vm.releases.count) релизов")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if vm.hasActiveFilters {
                        Text("фильтры активны")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(vm.releases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            ReleaseLibraryContextMenu(
                                appState: appState,
                                release: release,
                                pendingReleaseIds: $pendingReleaseIds
                            )
                        }
                        .onAppear {
                            Task { await vm.loadMoreIfNeeded(current: release, api: appState.api) }
                        }
                    }
                }
                .padding()

                if vm.isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.bottom, 20)
                } else if vm.canLoadMore() {
                    Button {
                        Task { await vm.loadMore(api: appState.api) }
                    } label: {
                        Text("Показать ещё")
                            .padding(.horizontal, 24)
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

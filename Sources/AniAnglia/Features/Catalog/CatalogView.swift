import SwiftUI

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var releases: [Release] = []
    @Published var page = 0
    @Published var totalPages: Int?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var sort: Int = 3 // Popular
    @Published var category: Int? = nil
    @Published var status: Int? = nil
    @Published var startYear: Int? = nil
    @Published var endYear: Int? = nil
    @Published var genres: Set<String> = []
    @Published var excludeGenres: Bool = false

    func reload(api: AnixartAPI) async {
        page = 0
        releases = []
        totalPages = nil
        errorMessage = nil
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.filter(
                page: 0,
                sort: sort,
                category: category,
                status: status,
                startYear: startYear,
                endYear: endYear,
                genres: Array(genres),
                excludeGenres: excludeGenres
            )
            releases = resp.items
            totalPages = resp.totalPageCount
            // totalPageCount may be nil -> we treat as single page until proven otherwise
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(api: AnixartAPI) async {
        if isLoading { return }
        guard canLoadMore() else { return }
        isLoading = true
        defer { isLoading = false }
        let next = page + 1
        do {
            let resp = try await api.filter(
                page: next,
                sort: sort,
                category: category,
                status: status,
                startYear: startYear,
                endYear: endYear,
                genres: Array(genres),
                excludeGenres: excludeGenres
            )
            // Only append if we got data; if empty, consider pagination finished
            if resp.items.isEmpty {
                totalPages = next // cap pagination
            } else {
                releases.append(contentsOf: resp.items)
                page = next
                totalPages = resp.totalPageCount
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canLoadMore() -> Bool {
        if releases.isEmpty { return false }
        if let total = totalPages {
            if total <= 0 { return false }
            return page + 1 < total
        }
        // Unknown total – allow next fetch; server will return empty when exhausted
        return true
    }
}

struct CatalogView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = CatalogViewModel()

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
    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(stride(from: currentYear, through: 1960, by: -1))
    }

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
        .task {
            if vm.releases.isEmpty {
                await vm.reload(api: appState.api)
            }
        }
    }

    private var filtersBar: some View {
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

            Button("Применить") {
                Task { await vm.reload(api: appState.api) }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(vm.releases) { release in
                        NavigationLink(value: release) {
                            ReleaseCard(release: release)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()

                if vm.canLoadMore() {
                    Button {
                        Task { await vm.loadMore(api: appState.api) }
                    } label: {
                        if vm.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Показать ещё")
                                .padding(.horizontal, 24)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoading)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

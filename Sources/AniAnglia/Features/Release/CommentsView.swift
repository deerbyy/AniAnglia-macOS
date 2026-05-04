import SwiftUI

@MainActor
final class CommentsViewModel: ObservableObject {
    let releaseId: Int64
    @Published var comments: [ReleaseComment] = []
    @Published var sort: Int = 2 // 0=new, 1=old, 2=top
    @Published var isLoading = false
    @Published var page = 0
    @Published var totalPages: Int?
    @Published var errorMessage: String?

    init(releaseId: Int64) {
        self.releaseId = releaseId
    }

    func reload(api: AnixartAPI) async {
        isLoading = true
        page = 0
        errorMessage = nil
        do {
            let resp = try await api.releaseComments(releaseId: releaseId, page: 0, sort: sort)
            comments = resp.content
            totalPages = resp.totalPageCount
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore(api: AnixartAPI) async {
        guard !isLoading, canLoadMore else { return }
        isLoading = true
        let next = page + 1
        do {
            let resp = try await api.releaseComments(releaseId: releaseId, page: next, sort: sort)
            comments.append(contentsOf: resp.content)
            page = next
            totalPages = resp.totalPageCount
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var canLoadMore: Bool {
        guard let total = totalPages else { return true }
        return page + 1 < total
    }
}

struct CommentsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: CommentsViewModel

    init(releaseId: Int64) {
        _vm = StateObject(wrappedValue: CommentsViewModel(releaseId: releaseId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Комментарии")
                    .font(.title3.bold())
                if let total = vm.totalPages, total > 0 {
                    Text("(\(vm.comments.count))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Сортировка", selection: $vm.sort) {
                    Text("Популярные").tag(2)
                    Text("Новые").tag(0)
                    Text("Старые").tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .onChange(of: vm.sort) { _ in
                    Task { await vm.reload(api: appState.api) }
                }
            }

            if vm.comments.isEmpty && vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
            } else if vm.comments.isEmpty {
                Text("Пока нет комментариев")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(vm.comments) { comment in
                        CommentRow(comment: comment)
                    }
                    if vm.canLoadMore {
                        Button {
                            Task { await vm.loadMore(api: appState.api) }
                        } label: {
                            HStack {
                                if vm.isLoading { ProgressView().controlSize(.small) }
                                Text("Показать ещё")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .task { await vm.reload(api: appState.api) }
    }
}

private struct CommentRow: View {
    let comment: ReleaseComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(url: comment.profile?.avatarURL, contentMode: .fill) {
                Circle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.profile?.login ?? "—")
                        .font(.callout.bold())
                    Text(comment.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if comment.isEdited == true {
                        Text("(ред.)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let ep = comment.postedAtEpisode, ep > 0 {
                        Text("после \(ep) серии")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let likes = comment.likesCount, likes > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text("\(likes)").font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                if comment.isSpoiler == true {
                    SpoilerText(text: comment.message)
                } else {
                    Text(comment.message)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let replies = comment.replyCount, replies > 0 {
                    Text("Ответов: \(replies)")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SpoilerText: View {
    let text: String
    @State private var revealed = false

    var body: some View {
        if revealed {
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Button {
                revealed = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                    Text("Спойлер — нажми, чтобы показать")
                }
                .font(.callout)
                .padding(8)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }
}

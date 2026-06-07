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

    // Compose state
    @Published var draft: String = ""
    @Published var draftSpoiler: Bool = false
    @Published var isPosting: Bool = false
    @Published var postError: String?

    /// Local override of vote state for snappy UI (commentId -> +1/-1).
    @Published var voteOverrides: [Int64: Int] = [:]

    @Published var replies: [Int64: [ReleaseComment]] = [:]
    @Published var replyPages: [Int64: Int] = [:]
    @Published var replyTotalPages: [Int64: Int] = [:]
    @Published var expandedReplyIds: Set<Int64> = []
    @Published var loadingReplyIds: Set<Int64> = []
    @Published var replyDrafts: [Int64: String] = [:]
    @Published var replySpoilers: Set<Int64> = []
    @Published var postingReplyIds: Set<Int64> = []
    @Published var replyErrors: [Int64: String] = [:]
    @Published var activeReplyComposerId: Int64?
    @Published var activeEditCommentId: Int64?
    @Published var editDrafts: [Int64: String] = [:]
    @Published var editSpoilers: Set<Int64> = []
    @Published var editErrors: [Int64: String] = [:]
    @Published var updatingCommentIds: Set<Int64> = []
    @Published var deletingCommentIds: Set<Int64> = []

    init(releaseId: Int64) {
        self.releaseId = releaseId
    }

    func currentVote(for comment: ReleaseComment) -> Int {
        if let v = voteOverrides[comment.id] { return v }
        return comment.vote ?? 0
    }

    func vote(_ comment: ReleaseComment, value: Int, api: AnixartAPI) async {
        let current = currentVote(for: comment)
        let next = current == value ? 0 : value // tap same again to undo
        voteOverrides[comment.id] = next
        do {
            _ = try await api.voteComment(commentId: comment.id, value: next)
        } catch {
            voteOverrides[comment.id] = current
            errorMessage = error.localizedDescription
        }
    }

    func submitDraft(api: AnixartAPI) async -> Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        isPosting = true
        postError = nil
        defer { isPosting = false }
        do {
            let resp = try await api.addComment(releaseId: releaseId, message: trimmed, parentCommentId: nil, isSpoiler: draftSpoiler)
            if resp.code == 0 {
                draft = ""
                draftSpoiler = false
                await reload(api: api)
                return true
            } else {
                postError = resp.message ?? "Не удалось отправить (code=\(resp.code))"
                return false
            }
        } catch {
            postError = error.localizedDescription
            return false
        }
    }

    func toggleReplies(for comment: ReleaseComment, api: AnixartAPI) async {
        if expandedReplyIds.contains(comment.id) {
            expandedReplyIds.remove(comment.id)
            return
        }
        expandedReplyIds.insert(comment.id)
        if replies[comment.id] == nil {
            await loadReplies(for: comment, page: 0, replace: true, api: api)
        }
    }

    func loadMoreReplies(for comment: ReleaseComment, api: AnixartAPI) async {
        guard !loadingReplyIds.contains(comment.id), canLoadMoreReplies(for: comment) else { return }
        await loadReplies(for: comment, page: (replyPages[comment.id] ?? 0) + 1, replace: false, api: api)
    }

    func toggleReplyComposer(for comment: ReleaseComment) {
        activeReplyComposerId = activeReplyComposerId == comment.id ? nil : comment.id
        replyErrors[comment.id] = nil
    }

    func submitReply(to comment: ReleaseComment, api: AnixartAPI) async -> Bool {
        let trimmed = (replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        postingReplyIds.insert(comment.id)
        replyErrors[comment.id] = nil
        defer { postingReplyIds.remove(comment.id) }

        do {
            let resp = try await api.addComment(
                releaseId: releaseId,
                message: trimmed,
                parentCommentId: comment.id,
                isSpoiler: replySpoilers.contains(comment.id)
            )
            if resp.code == 0 {
                replyDrafts[comment.id] = ""
                replySpoilers.remove(comment.id)
                activeReplyComposerId = nil
                expandedReplyIds.insert(comment.id)
                await loadReplies(for: comment, page: 0, replace: true, api: api)
                return true
            }
            replyErrors[comment.id] = resp.message ?? "Не удалось отправить ответ (code=\(resp.code))"
            return false
        } catch {
            replyErrors[comment.id] = error.localizedDescription
            return false
        }
    }

    func beginEditing(_ comment: ReleaseComment) {
        if activeEditCommentId == comment.id {
            activeEditCommentId = nil
            return
        }
        activeEditCommentId = comment.id
        editDrafts[comment.id] = comment.message
        if comment.isSpoiler == true {
            editSpoilers.insert(comment.id)
        } else {
            editSpoilers.remove(comment.id)
        }
        editErrors[comment.id] = nil
    }

    func cancelEditing(_ comment: ReleaseComment) {
        if activeEditCommentId == comment.id {
            activeEditCommentId = nil
        }
        editErrors[comment.id] = nil
    }

    func submitEdit(_ comment: ReleaseComment, parent: ReleaseComment?, api: AnixartAPI) async -> Bool {
        let trimmed = (editDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        updatingCommentIds.insert(comment.id)
        editErrors[comment.id] = nil
        defer { updatingCommentIds.remove(comment.id) }

        do {
            let resp = try await api.editComment(
                commentId: comment.id,
                message: trimmed,
                isSpoiler: editSpoilers.contains(comment.id)
            )
            if resp.code == 0 {
                replaceComment(comment.edited(message: trimmed, isSpoiler: editSpoilers.contains(comment.id)), parent: parent)
                activeEditCommentId = nil
                return true
            }
            editErrors[comment.id] = resp.message ?? "Не удалось сохранить (code=\(resp.code))"
            return false
        } catch {
            editErrors[comment.id] = error.localizedDescription
            return false
        }
    }

    func delete(_ comment: ReleaseComment, parent: ReleaseComment?, api: AnixartAPI) async {
        deletingCommentIds.insert(comment.id)
        defer { deletingCommentIds.remove(comment.id) }

        do {
            _ = try await api.deleteComment(commentId: comment.id)
            removeComment(comment, parent: parent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isUpdating(_ comment: ReleaseComment) -> Bool {
        updatingCommentIds.contains(comment.id)
    }

    func isDeleting(_ comment: ReleaseComment) -> Bool {
        deletingCommentIds.contains(comment.id)
    }

    func isRepliesExpanded(for comment: ReleaseComment) -> Bool {
        expandedReplyIds.contains(comment.id)
    }

    func isLoadingReplies(for comment: ReleaseComment) -> Bool {
        loadingReplyIds.contains(comment.id)
    }

    func isPostingReply(to comment: ReleaseComment) -> Bool {
        postingReplyIds.contains(comment.id)
    }

    func canLoadMoreReplies(for comment: ReleaseComment) -> Bool {
        guard expandedReplyIds.contains(comment.id) else { return false }
        if let total = replyTotalPages[comment.id] {
            return (replyPages[comment.id] ?? 0) + 1 < total
        }
        if let expected = comment.replyCount {
            return (replies[comment.id]?.count ?? 0) < expected
        }
        return false
    }

    private func loadReplies(for comment: ReleaseComment, page: Int, replace: Bool, api: AnixartAPI) async {
        loadingReplyIds.insert(comment.id)
        defer { loadingReplyIds.remove(comment.id) }

        do {
            let resp = try await api.commentReplies(commentId: comment.id, page: page)
            if replace {
                replies[comment.id] = resp.content
            } else {
                replies[comment.id, default: []].append(contentsOf: resp.content)
            }
            replyPages[comment.id] = page
            if let total = resp.totalPageCount {
                replyTotalPages[comment.id] = total
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceComment(_ edited: ReleaseComment, parent: ReleaseComment?) {
        if let parent {
            guard var items = replies[parent.id],
                  let index = items.firstIndex(where: { $0.id == edited.id }) else { return }
            items[index] = edited
            replies[parent.id] = items
        } else if let index = comments.firstIndex(where: { $0.id == edited.id }) {
            comments[index] = edited
        }
    }

    private func removeComment(_ comment: ReleaseComment, parent: ReleaseComment?) {
        if let parent {
            replies[parent.id]?.removeAll { $0.id == comment.id }
        } else {
            comments.removeAll { $0.id == comment.id }
            replies[comment.id] = nil
            expandedReplyIds.remove(comment.id)
        }

        voteOverrides[comment.id] = nil
        replyDrafts[comment.id] = nil
        replyErrors[comment.id] = nil
        editDrafts[comment.id] = nil
        editErrors[comment.id] = nil
        editSpoilers.remove(comment.id)
        replySpoilers.remove(comment.id)
        if activeEditCommentId == comment.id { activeEditCommentId = nil }
        if activeReplyComposerId == comment.id { activeReplyComposerId = nil }
    }

    func reload(api: AnixartAPI) async {
        isLoading = true
        page = 0
        errorMessage = nil
        do {
            let resp = try await api.releaseComments(releaseId: releaseId, page: 0, sort: sort)
            comments = resp.content
            totalPages = resp.totalPageCount
            resetReplyState()
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

    private func resetReplyState() {
        replies = [:]
        replyPages = [:]
        replyTotalPages = [:]
        expandedReplyIds = []
        loadingReplyIds = []
        replyDrafts = [:]
        replySpoilers = []
        postingReplyIds = []
        replyErrors = [:]
        activeReplyComposerId = nil
        activeEditCommentId = nil
        editDrafts = [:]
        editSpoilers = []
        editErrors = [:]
        updatingCommentIds = []
        deletingCommentIds = []
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

            if appState.auth.isAuthenticated {
                composer
            } else {
                Text("Чтобы оставить комментарий, войди в аккаунт через кнопку «Войти» справа сверху.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        commentThread(for: comment)
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

    @ViewBuilder
    private func commentThread(for comment: ReleaseComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CommentRow(
                comment: comment,
                currentVote: vm.currentVote(for: comment),
                canVote: appState.auth.isAuthenticated,
                canManage: isOwn(comment),
                isDeleting: vm.isDeleting(comment),
                onVote: { value in
                    Task { await vm.vote(comment, value: value, api: appState.api) }
                },
                onEdit: {
                    vm.beginEditing(comment)
                },
                onDelete: {
                    Task { await vm.delete(comment, parent: nil, api: appState.api) }
                }
            )

            if vm.activeEditCommentId == comment.id {
                editComposer(for: comment, parent: nil)
                    .padding(.leading, 46)
            }

            HStack(spacing: 12) {
                if appState.auth.isAuthenticated {
                    Button {
                        vm.toggleReplyComposer(for: comment)
                    } label: {
                        Label("Ответить", systemImage: "arrowshape.turn.up.left")
                    }
                    .buttonStyle(.plain)
                }

                if (comment.replyCount ?? 0) > 0 || !(vm.replies[comment.id] ?? []).isEmpty {
                    Button {
                        Task { await vm.toggleReplies(for: comment, api: appState.api) }
                    } label: {
                        HStack(spacing: 5) {
                            if vm.isLoadingReplies(for: comment) {
                                ProgressView().controlSize(.small)
                            }
                            Image(systemName: vm.isRepliesExpanded(for: comment) ? "chevron.down" : "chevron.right")
                            Text(vm.isRepliesExpanded(for: comment) ? "Скрыть ответы" : "Ответы: \(comment.replyCount ?? 0)")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.caption)
            .foregroundStyle(.tint)
            .padding(.leading, 46)

            if vm.activeReplyComposerId == comment.id {
                replyComposer(for: comment)
                    .padding(.leading, 46)
            }

            if vm.isRepliesExpanded(for: comment) {
                repliesList(for: comment)
                    .padding(.leading, 46)
            }
        }
    }

    @ViewBuilder
    private func repliesList(for comment: ReleaseComment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(vm.replies[comment.id] ?? []) { reply in
                replyRow(reply, parent: comment)
            }

            if vm.isLoadingReplies(for: comment) && (vm.replies[comment.id] ?? []).isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 6)
            }

            if vm.canLoadMoreReplies(for: comment) {
                Button {
                    Task { await vm.loadMoreReplies(for: comment, api: appState.api) }
                } label: {
                    HStack(spacing: 6) {
                        if vm.isLoadingReplies(for: comment) {
                            ProgressView().controlSize(.small)
                        }
                        Text("Показать ещё ответы")
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 2)
        }
    }

    @ViewBuilder
    private func replyRow(_ reply: ReleaseComment, parent: ReleaseComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CommentRow(
                comment: reply,
                currentVote: vm.currentVote(for: reply),
                canVote: appState.auth.isAuthenticated,
                canManage: isOwn(reply),
                isDeleting: vm.isDeleting(reply),
                onVote: { value in
                    Task { await vm.vote(reply, value: value, api: appState.api) }
                },
                onEdit: {
                    vm.beginEditing(reply)
                },
                onDelete: {
                    Task { await vm.delete(reply, parent: parent, api: appState.api) }
                }
            )

            if vm.activeEditCommentId == reply.id {
                editComposer(for: reply, parent: parent)
            }
        }
    }

    @ViewBuilder
    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if vm.draft.isEmpty {
                    Text("Напиши свой комментарий…")
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.draft)
                    .frame(minHeight: 60, maxHeight: 120)
                    .padding(4)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                Toggle("Спойлер", isOn: $vm.draftSpoiler)
                    .toggleStyle(.checkbox)
                if let err = vm.postError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Spacer()
                Button {
                    Task { _ = await vm.submitDraft(api: appState.api) }
                } label: {
                    if vm.isPosting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Отправить")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isPosting || vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func replyComposer(for comment: ReleaseComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if (vm.replyDrafts[comment.id] ?? "").isEmpty {
                    Text("Ответить \(comment.profile?.displayName ?? "пользователю")…")
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: replyDraftBinding(for: comment.id))
                    .frame(minHeight: 54, maxHeight: 100)
                    .padding(4)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Toggle("Спойлер", isOn: replySpoilerBinding(for: comment.id))
                    .toggleStyle(.checkbox)
                if let err = vm.replyErrors[comment.id] {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Spacer()
                Button("Отмена") {
                    vm.toggleReplyComposer(for: comment)
                }
                .buttonStyle(.borderless)
                Button {
                    Task { _ = await vm.submitReply(to: comment, api: appState.api) }
                } label: {
                    if vm.isPostingReply(to: comment) {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Ответить")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    vm.isPostingReply(to: comment)
                    || (vm.replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private func replyDraftBinding(for commentId: Int64) -> Binding<String> {
        Binding(
            get: { vm.replyDrafts[commentId] ?? "" },
            set: { vm.replyDrafts[commentId] = $0 }
        )
    }

    private func replySpoilerBinding(for commentId: Int64) -> Binding<Bool> {
        Binding(
            get: { vm.replySpoilers.contains(commentId) },
            set: { isOn in
                if isOn {
                    vm.replySpoilers.insert(commentId)
                } else {
                    vm.replySpoilers.remove(commentId)
                }
            }
        )
    }

    @ViewBuilder
    private func editComposer(for comment: ReleaseComment, parent: ReleaseComment?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: editDraftBinding(for: comment.id))
                .frame(minHeight: 54, maxHeight: 120)
                .padding(4)
                .scrollContentBackground(.hidden)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Toggle("Спойлер", isOn: editSpoilerBinding(for: comment.id))
                    .toggleStyle(.checkbox)
                if let err = vm.editErrors[comment.id] {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Spacer()
                Button("Отмена") {
                    vm.cancelEditing(comment)
                }
                .buttonStyle(.borderless)
                Button {
                    Task { _ = await vm.submitEdit(comment, parent: parent, api: appState.api) }
                } label: {
                    if vm.isUpdating(comment) {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Сохранить")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    vm.isUpdating(comment)
                    || (vm.editDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private func editDraftBinding(for commentId: Int64) -> Binding<String> {
        Binding(
            get: { vm.editDrafts[commentId] ?? "" },
            set: { vm.editDrafts[commentId] = $0 }
        )
    }

    private func editSpoilerBinding(for commentId: Int64) -> Binding<Bool> {
        Binding(
            get: { vm.editSpoilers.contains(commentId) },
            set: { isOn in
                if isOn {
                    vm.editSpoilers.insert(commentId)
                } else {
                    vm.editSpoilers.remove(commentId)
                }
            }
        )
    }

    private func isOwn(_ comment: ReleaseComment) -> Bool {
        guard let profileId = appState.auth.profileId else { return false }
        return comment.profile?.id == profileId
    }
}

private struct CommentRow: View {
    let comment: ReleaseComment
    let currentVote: Int
    let canVote: Bool
    let canManage: Bool
    let isDeleting: Bool
    let onVote: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var displayedScore: Int {
        let base = (comment.voteCount ?? 0)
        let serverVote = comment.vote ?? 0
        return base - serverVote + currentVote
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAuthorAvatarLink(profile: comment.profile, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    CommentAuthorNameLink(profile: comment.profile, font: .callout.bold())
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
                    if canManage {
                        Menu {
                            Button {
                                onEdit()
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            if isDeleting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .disabled(isDeleting)
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
                HStack(spacing: 12) {
                    Button {
                        onVote(1)
                    } label: {
                        Image(systemName: currentVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .foregroundStyle(currentVote == 1 ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canVote)

                    Text("\(displayedScore)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20)

                    Button {
                        onVote(-1)
                    } label: {
                        Image(systemName: currentVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .foregroundStyle(currentVote == -1 ? Color.red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canVote)

                }
                .font(.callout)
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

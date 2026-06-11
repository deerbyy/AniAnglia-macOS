import SwiftUI

struct CommentAuthorAvatarLink: View {
    let profile: CommentProfile?
    let size: CGFloat

    var body: some View {
        linkedToProfile {
            RemoteImage(url: profile?.avatarURL, contentMode: .fill) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func linkedToProfile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let route = profileRoute {
            NavigationLink(value: route) {
                content()
            }
            .buttonStyle(.plain)
            .help("Открыть профиль \(profile?.displayName ?? "")")
        } else {
            content()
        }
    }

    private var profileRoute: ProfileRoute? {
        guard let profile, profile.id > 0 else { return nil }
        return ProfileRoute(id: profile.id)
    }
}

struct CommentAuthorNameLink: View {
    let profile: CommentProfile?
    let font: Font

    var body: some View {
        linkedToProfile {
            Text(profile?.displayName ?? "-")
                .font(font)
                .foregroundStyle(profileRoute == nil ? .secondary : .primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func linkedToProfile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let route = profileRoute {
            NavigationLink(value: route) {
                content()
            }
            .buttonStyle(.plain)
            .help("Открыть профиль \(profile?.displayName ?? "")")
        } else {
            content()
        }
    }

    private var profileRoute: ProfileRoute? {
        guard let profile, profile.id > 0 else { return nil }
        return ProfileRoute(id: profile.id)
    }
}

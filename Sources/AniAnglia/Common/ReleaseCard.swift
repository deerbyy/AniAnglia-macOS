import SwiftUI

struct ReleaseCard: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: release.posterURL, contentMode: .fill) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
                .frame(width: 160, height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let badge = bookmarkBadge {
                    Text(badge.title)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .foregroundStyle(.white)
                        .background(badge.color)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }

            }
            .overlay(alignment: .topTrailing) {
                if release.isFavorite == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .padding(6)
                        .foregroundStyle(.yellow)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                        .padding(6)
                }
            }
            Text(release.displayTitle)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
            if let year = release.year {
                Text(year)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bookmarkBadge: (title: String, color: Color)? {
        guard let rawValue = release.profileListStatus,
              let category = BookmarkCategory(rawValue: rawValue) else { return nil }
        return (category.title, category.color)
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

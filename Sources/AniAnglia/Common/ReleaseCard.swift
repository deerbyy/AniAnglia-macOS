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
        switch release.profileListStatus {
        case 1: return ("В планах", .yellow)
        case 2: return ("Смотрю", .indigo)
        case 3: return ("Просмотрено", .green)
        case 4: return ("Отложено", .purple)
        case 5: return ("Брошено", .red)
        default: return nil
        }
    }
}

import SwiftUI

struct CollectionCard: View {
    let collection: AnixartCollection
    var style: Style = .regular

    enum Style {
        case compact
        case regular
    }

    private var imageSize: CGSize {
        switch style {
        case .compact: return CGSize(width: 220, height: 124)
        case .regular: return CGSize(width: 260, height: 146)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RemoteImage(url: collection.imageURL, contentMode: .fill) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.14))
                        .overlay(
                            Image(systemName: "rectangle.stack")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        )
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if collection.isFavorite == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .padding(6)
                        .foregroundStyle(.yellow)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                        .padding(6)
                }
            }

            Text(collection.title)
                .font(.system(size: style == .compact ? 12 : 13, weight: .semibold))
                .lineLimit(2)
                .frame(width: imageSize.width, alignment: .leading)

            HStack(spacing: 10) {
                if !collection.releases.isEmpty {
                    Label("\(collection.releases.count)", systemImage: "play.rectangle")
                }
                if let favoriteCount = collection.favoriteCount {
                    Label("\(favoriteCount)", systemImage: "star")
                }
                if let commentCount = collection.commentCount {
                    Label("\(commentCount)", systemImage: "text.bubble")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: imageSize.width, alignment: .leading)
        }
    }
}

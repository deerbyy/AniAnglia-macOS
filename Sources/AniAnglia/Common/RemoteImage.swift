import SwiftUI
import AppKit

/// Cached async image loader using NSCache + URLSession.
@MainActor
final class RemoteImageCache {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, NSImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 96 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> NSImage? {
        if let cached = image(for: url) { return cached }
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = NSImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL, cost: data.count)
            return image
        } catch {
            return nil
        }
    }
}

struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholder: Placeholder

    @State private var image: NSImage?

    init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            if let cached = RemoteImageCache.shared.image(for: url) {
                image = cached
                return
            }
            image = await RemoteImageCache.shared.load(url)
        }
    }
}

extension RemoteImage where Placeholder == AnyView {
    init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) {
            AnyView(
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .overlay(ProgressView().controlSize(.small))
            )
        }
    }
}

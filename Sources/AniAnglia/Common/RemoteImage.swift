import SwiftUI
import AppKit

/// Cached async image loader using NSCache + URLSession.
/// Not @MainActor – image loading must not block the main thread.
/// Cache itself is thread-safe (NSCache), session is Sendable via @unchecked.
final class RemoteImageCache: @unchecked Sendable {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, NSImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 96 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> NSImage? {
        if let cached = image(for: url) { return cached }
        do {
            let (data, response) = try await session.data(from: url)
            // Validate HTTP response is image-like (200 and non-empty)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard !data.isEmpty, let image = NSImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL, cost: data.count)
            return image
        } catch {
            return nil
        }
    }

    func clear() {
        cache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
        // Also clear the custom session's cache
        session.configuration.urlCache?.removeAllCachedResponses()
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
            // Load off-main without blocking UI; cache is Sendable
            let loaded = await RemoteImageCache.shared.load(url)
            // Avoid overwriting if task was cancelled / URL changed
            if !Task.isCancelled {
                image = loaded
            }
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

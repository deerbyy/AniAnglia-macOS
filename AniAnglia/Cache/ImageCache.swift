import AppKit
import Foundation
import SwiftUI

@MainActor
final class ImageCache: ObservableObject {
    private let cache = NSCache<NSURL, NSImage>()
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        cache.countLimit = 250
        URLCache.shared.memoryCapacity = 64 * 1024 * 1024
        URLCache.shared.diskCapacity = 256 * 1024 * 1024
    }

    func image(for url: URL) async throws -> NSImage {
        let nsURL = url as NSURL
        if let cached = cache.object(forKey: nsURL) {
            return cached
        }
        let (data, _) = try await urlSession.data(from: url)
        guard let image = NSImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        cache.setObject(image, forKey: nsURL)
        return image
    }

    func clear() {
        cache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }
}

struct CachedRemoteImage: View {
    let urlString: String?
    let contentMode: ContentMode

    @EnvironmentObject private var imageCache: ImageCache
    @State private var image: NSImage?
    @State private var didFail = false

    init(urlString: String?, contentMode: ContentMode = .fill) {
        self.urlString = urlString
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(.quaternary)
                Image(systemName: didFail ? "photo" : "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        guard let url = URL.web(urlString) else {
            didFail = true
            return
        }
        do {
            image = try await imageCache.image(for: url)
            didFail = false
        } catch {
            didFail = true
        }
    }
}

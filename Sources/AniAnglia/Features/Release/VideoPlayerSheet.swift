import SwiftUI
import AppKit
import WebKit

struct VideoPlayerSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title ?? "Видео")
                        .font(.headline)
                    if let host = video.hosting?.name {
                        Text(host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let url = video.resolvedPlayerURL {
                    Link(destination: url) {
                        Label("Открыть в браузере", systemImage: "safari")
                    }
                    .padding(.trailing, 8)
                }
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding()
            Divider()
            if let url = video.resolvedPlayerURL {
                WebView(url: url)
            } else {
                Text("Нет URL для воспроизведения")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
    }
}

struct WebView: NSViewRepresentable {
    let url: URL

    private static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    private static let embedBaseURL = URL(string: "https://anixart.tv/")!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        let webview = WKWebView(frame: .zero, configuration: config)
        webview.navigationDelegate = context.coordinator
        webview.uiDelegate = context.coordinator
        webview.customUserAgent = Self.safariUserAgent
        webview.allowsBackForwardNavigationGestures = true
        return webview
    }

    func updateNSView(_ webview: WKWebView, context: Context) {
        let page = PlayerWebPage(url: url, baseURL: Self.embedBaseURL)
        guard context.coordinator.currentPageKey != page.key else { return }
        context.coordinator.currentPageKey = page.key

        switch page.load {
        case .iframeHTML(let html, let baseURL):
            webview.loadHTMLString(html, baseURL: baseURL)
        case .request(let request):
            webview.load(request)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var currentPageKey: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if ["http", "https", "about", "data", "blob"].contains(scheme) {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

private struct PlayerWebPage {
    enum Load {
        case request(URLRequest)
        case iframeHTML(String, baseURL: URL)
    }

    let key: String
    let load: Load

    init(url: URL, baseURL: URL) {
        let normalizedURL = url.normalizedPlayerURL
        let host = normalizedURL.host?.lowercased() ?? ""

        if let youtubeURL = normalizedURL.youtubeEmbedURL {
            // YouTube error 153 is produced when its embed navigation has no
            // HTTP Referer. Load the player request itself with that header.
            self.key = "youtube:\(youtubeURL.absoluteString)"
            self.load = .request(Self.request(for: youtubeURL, referer: baseURL))
        } else if host.isKnownIframePlayerHost {
            self.key = "iframe:\(normalizedURL.absoluteString)"
            self.load = .iframeHTML(Self.iframeHTML(for: normalizedURL), baseURL: baseURL)
        } else {
            self.key = "request:\(normalizedURL.absoluteString)"
            self.load = .request(Self.request(for: normalizedURL, referer: baseURL))
        }
    }

    private static func request(for url: URL, referer: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return request
    }

    private static func iframeHTML(for url: URL) -> String {
        let escapedURL = url.absoluteString.htmlAttributeEscaped
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: #000;
            }
            iframe {
              position: fixed;
              inset: 0;
              width: 100%;
              height: 100%;
              border: 0;
              background: #000;
            }
          </style>
        </head>
        <body>
          <iframe
            src="\(escapedURL)"
            allow="accelerometer; autoplay *; clipboard-write; encrypted-media *; fullscreen *; gyroscope; picture-in-picture *; web-share"
            allowfullscreen
            referrerpolicy="strict-origin-when-cross-origin">
          </iframe>
        </body>
        </html>
        """
    }
}

private extension URL {
    var normalizedPlayerURL: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        let host = components.host?.lowercased() ?? ""
        if host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" {
            components.scheme = "https"
            components.host = "www.youtube.com"
        } else if host == "youtu.be" {
            components.scheme = "https"
        }
        return components.url ?? self
    }

    var youtubeEmbedURL: URL? {
        guard let videoID = youtubeVideoID else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/embed/\(videoID)"
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "origin", value: "https://anixart.tv")
        ]

        if let start = youtubeStartTime {
            components.queryItems?.append(URLQueryItem(name: "start", value: String(start)))
        }
        return components.url
    }

    private var youtubeVideoID: String? {
        let host = self.host?.lowercased() ?? ""
        let parts = pathComponents.filter { $0 != "/" }

        if host == "youtu.be" {
            return parts.first?.nonEmptyPlayerToken
        }

        guard host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" else {
            return nil
        }

        if let index = parts.firstIndex(where: { ["embed", "shorts", "live"].contains($0) }),
           parts.indices.contains(index + 1) {
            return parts[index + 1].nonEmptyPlayerToken
        }

        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "v" })?.value?.nonEmptyPlayerToken
    }

    private var youtubeStartTime: Int? {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        guard let raw = components?.queryItems?.first(where: { ["start", "t"].contains($0.name) })?.value else {
            return nil
        }
        return raw.youtubeTimeOffset
    }
}

private extension String {
    var nonEmptyPlayerToken: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var htmlAttributeEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    var youtubeTimeOffset: Int? {
        if let seconds = Int(self) { return seconds }
        var total = 0
        var current = ""
        for char in lowercased() {
            if char.isNumber {
                current.append(char)
            } else if let value = Int(current) {
                switch char {
                case "h": total += value * 3600
                case "m": total += value * 60
                case "s": total += value
                default: break
                }
                current = ""
            }
        }
        if let value = Int(current) { total += value }
        return total > 0 ? total : nil
    }
}

private extension String {
    var isKnownIframePlayerHost: Bool {
        self == "kodikplayer.com"
            || hasSuffix(".kodikplayer.com")
            || self == "kodik.cc"
            || hasSuffix(".kodik.cc")
            || contains("libria.fun")
            || contains("anilibria")
    }
}

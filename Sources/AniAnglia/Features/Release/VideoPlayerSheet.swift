import SwiftUI
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

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        // WKWebView on macOS disables HTML5 element fullscreen by default,
        // so the fullscreen button of embedded players (Kodik/Sibnet/VK/YouTube)
        // silently does nothing. Enable it explicitly (public API since macOS 12.3).
        config.preferences.isElementFullscreenEnabled = true
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        let webview = WKWebView(frame: .zero, configuration: config)
        webview.allowsBackForwardNavigationGestures = false
        webview.allowsMagnification = false
        return webview
    }

    func updateNSView(_ webview: WKWebView, context: Context) {
        if webview.url != url {
            webview.load(URLRequest(url: url))
        }
    }
}

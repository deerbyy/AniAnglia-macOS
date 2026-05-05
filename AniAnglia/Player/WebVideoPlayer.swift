import AVKit
import SwiftUI
import WebKit

struct PlayerSession: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

struct WebVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsMagnification = true
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}

struct VideoPlayerSheet: View {
    let session: PlayerSession

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Link(destination: session.url) {
                    Label("Открыть", systemImage: "safari")
                }
            }
            .padding()

            WebVideoPlayer(url: session.url)
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}

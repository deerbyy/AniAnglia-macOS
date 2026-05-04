import SwiftUI

struct ScreenshotsViewer: View {
    let urls: [URL]
    let initialIndex: Int
    let onClose: () -> Void

    @State private var index: Int

    init(urls: [URL], initialIndex: Int, onClose: @escaping () -> Void) {
        self.urls = urls
        self.initialIndex = initialIndex
        self.onClose = onClose
        self._index = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !urls.isEmpty {
                RemoteImage(url: urls[safe: index], contentMode: .fit) {
                    ProgressView().tint(.white)
                }
                .padding(40)
            }

            VStack {
                HStack {
                    Spacer()
                    Text("\(index + 1) / \(urls.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                Spacer()
                HStack {
                    Button {
                        if index > 0 { index -= 1 }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                    }
                    .buttonStyle(.plain)
                    .disabled(index <= 0)
                    Spacer()
                    Button {
                        if index < urls.count - 1 { index += 1 }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= urls.count - 1)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

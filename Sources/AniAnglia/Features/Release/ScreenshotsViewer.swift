import SwiftUI

struct ScreenshotsViewer: View {
    let urls: [URL]
    let initialIndex: Int
    let onClose: () -> Void

    @State private var index: Int
    @State private var zoomScale: CGFloat = 1
    @State private var baseZoomScale: CGFloat = 1
    @State private var dragOffset: CGSize = .zero
    @State private var baseDragOffset: CGSize = .zero

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
                .scaleEffect(zoomScale)
                .offset(dragOffset)
                .gesture(dragGesture)
                .simultaneousGesture(zoomGesture)
            }

            VStack {
                HStack {
                    zoomControls
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
        .onChange(of: index) { _ in
            resetZoom()
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 10) {
            Button {
                setZoom(zoomScale - 0.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Уменьшить")

            Text("\(Int(zoomScale * 100))%")
                .font(.caption.bold().monospacedDigit())
                .frame(width: 48)

            Button {
                setZoom(zoomScale + 0.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Увеличить")

            Button {
                resetZoom()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Сбросить масштаб")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoomScale > 1 else { return }
                dragOffset = CGSize(
                    width: baseDragOffset.width + value.translation.width,
                    height: baseDragOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                baseDragOffset = dragOffset
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = clampedZoom(baseZoomScale * value)
                if zoomScale <= 1 {
                    dragOffset = .zero
                    baseDragOffset = .zero
                }
            }
            .onEnded { value in
                setZoom(baseZoomScale * value)
            }
    }

    private func setZoom(_ value: CGFloat) {
        zoomScale = clampedZoom(value)
        baseZoomScale = zoomScale
        if zoomScale <= 1 {
            dragOffset = .zero
            baseDragOffset = .zero
        }
    }

    private func resetZoom() {
        zoomScale = 1
        baseZoomScale = 1
        dragOffset = .zero
        baseDragOffset = .zero
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

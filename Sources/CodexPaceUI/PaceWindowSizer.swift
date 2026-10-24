import AppKit
import Combine

/// Keeps the native window in step with the measured SwiftUI content, including
/// disclosure changes that do not reliably update a Scene's content-size limits.
@MainActor
public final class PaceWindowSizer: ObservableObject {
    public weak var window: NSWindow? {
        didSet {
            guard window !== oldValue else { return }
            resizeObserver = nil
            if allowsManualResize, let window {
                resizeObserver = NotificationCenter.default.publisher(
                    for: NSWindow.willStartLiveResizeNotification, object: window
                ).sink { [weak self] _ in
                    MainActor.assumeIsolated { self?.isManuallySized = true }
                }
            }
            resizeToContent()
        }
    }
    @Published public private(set) var isManuallySized = false
    private let allowsManualResize: Bool
    private var resizeObserver: AnyCancellable?
    private var contentSize: CGSize = .zero

    public init(allowsManualResize: Bool = false) {
        self.allowsManualResize = allowsManualResize
    }

    public func usePreset(scale: CGFloat) {
        guard let window else { return }
        isManuallySized = false
        let width = PaceMenuLayout.width * scale
        if contentSize != .zero {
            let ratio = width / contentSize.width
            contentSize = CGSize(width: width, height: contentSize.height * ratio)
            resizeToContent()
        } else {
            window.setContentSize(CGSize(width: width, height: window.contentLayoutRect.height))
        }
    }

    public func updateContentSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite else { return }
        contentSize = size
        resizeToContent()
    }

    private func resizeToContent() {
        guard let window, contentSize != .zero, !isManuallySized else { return }
        let previous = window.frame
        let chromeHeight = previous.height - window.contentLayoutRect.height
        let desiredSize = CGSize(width: ceil(contentSize.width), height: ceil(contentSize.height) + chromeHeight)
        guard abs(previous.width - desiredSize.width) > 0.5 ||
              abs(previous.height - desiredSize.height) > 0.5 else { return }

        var frame = CGRect(x: previous.minX, y: previous.maxY - desiredSize.height,
                           width: desiredSize.width, height: desiredSize.height)
        if let screen = window.screen {
            frame = WindowFramePlacement.frameKeepingResizeVisible(
                resizedFrame: frame, previousFrame: previous, visibleFrame: screen.visibleFrame,
                preservesRightEdge: desiredSize.width < previous.width
            )
        }
        window.setFrame(frame, display: true)
    }
}

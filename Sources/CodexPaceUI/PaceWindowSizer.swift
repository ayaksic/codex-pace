import AppKit

/// Keeps the native window in step with the measured SwiftUI content, including
/// disclosure changes that do not reliably update a Scene's content-size limits.
@MainActor
public final class PaceWindowSizer: ObservableObject {
    public weak var window: NSWindow? {
        didSet { resizeToContent() }
    }
    private var contentSize: CGSize = .zero

    public init() {}

    public func updateContentSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite else { return }
        contentSize = size
        resizeToContent()
    }

    private func resizeToContent() {
        guard let window, contentSize != .zero else { return }
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

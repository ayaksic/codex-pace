import AppKit

/// Popovers fit content automatically. Main windows fit changed content at the
/// chosen width, while scale-only measurements never undo a manual resize.
@MainActor
public final class PaceWindowSizer: ObservableObject {
    public weak var window: NSWindow? {
        didSet {
            guard window !== oldValue else { return }
            if allowsManualResize {
                lockContentAspectRatio()
            } else {
                resize(to: contentSize)
            }
        }
    }
    private let allowsManualResize: Bool
    private var contentSize: CGSize = .zero
    private var pendingPresetScale: CGFloat?

    public init(allowsManualResize: Bool = false) {
        self.allowsManualResize = allowsManualResize
    }

    public func usePreset(scale: CGFloat) {
        guard window != nil else { return }
        guard contentSize != .zero else {
            pendingPresetScale = scale
            return
        }
        pendingPresetScale = nil
        fitContent(width: PaceMenuLayout.width * scale)
    }

    private func fitContent(width: CGFloat) {
        guard let window, contentSize != .zero else { return }
        let ratio = width / contentSize.width
        var height = contentSize.height * ratio
        if let screen = window.screen {
            let chromeHeight = window.frame.height - window.contentLayoutRect.height
            height = min(height, screen.visibleFrame.height - chromeHeight)
        }
        resize(to: CGSize(width: width, height: max(PaceMenuLayout.minimumWindowHeight, height)))
        lockContentAspectRatio()
    }

    public func updateContentSize(_ size: CGSize, resizeForContentChanges: Bool = true) {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite else { return }
        // Normalize away display scale so delayed measurements from a preset
        // or user drag cannot pull the window back to an earlier size.
        let previousHeight = contentSize.width > 0
            ? contentSize.height / contentSize.width * PaceMenuLayout.width : nil
        let naturalHeight = size.height / size.width * PaceMenuLayout.width
        contentSize = size
        if let pendingPresetScale {
            usePreset(scale: pendingPresetScale)
        } else if !allowsManualResize {
            resize(to: size)
        } else if resizeForContentChanges, let previousHeight,
                  abs(naturalHeight - previousHeight) > 0.5, let window {
            fitContent(width: window.contentLayoutRect.width)
        }
    }

    private func lockContentAspectRatio() {
        guard allowsManualResize, let window else { return }
        // AppKit constrains user drags without intercepting SwiftUI's window
        // delegate. Use the actual content rect, including any full-size content
        // title-bar area, and the final screen-clamped size after fitting.
        window.contentAspectRatio = window.contentRect(forFrameRect: window.frame).size
    }

    private func resize(to size: CGSize) {
        guard let window, size != .zero else { return }
        let previous = window.frame
        let chromeHeight = previous.height - window.contentLayoutRect.height
        let desiredSize = CGSize(width: ceil(size.width), height: ceil(size.height) + chromeHeight)
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

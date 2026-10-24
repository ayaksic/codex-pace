import AppKit
import SwiftUI

/// Width controls the continuous scale. A shorter manually sized window scrolls
/// instead of shrinking text or hiding controls.
public struct PaceMainWindowView: View {
    @ObservedObject private var model: PaceViewModel
    @Binding private var isLargeDisplay: Bool
    @StateObject private var sizer = PaceWindowSizer(allowsManualResize: true)
    @State private var maximumContentHeight = (NSScreen.main?.visibleFrame.height ?? 800) - 40

    public init(model: PaceViewModel, isLargeDisplay: Binding<Bool>) {
        self.model = model
        self._isLargeDisplay = isLargeDisplay
    }

    public var body: some View {
        GeometryReader { geometry in
            PaceMenuView(
                model: model,
                isLargeDisplay: $isLargeDisplay,
                maximumHeight: sizer.isManuallySized ? geometry.size.height : maximumContentHeight,
                displayScale: geometry.size.width / PaceMenuLayout.width
            )
        }
        .frame(minWidth: 480, minHeight: 240)
        .background {
            MainWindowAccessor { window in
                guard sizer.window !== window else { return }
                sizer.window = window
                updateScreenLimit()
                sizer.usePreset(scale: isLargeDisplay ? 2 : 1)
            }
        }
        .onPreferenceChange(PaceContentSizeKey.self) { size in
            DispatchQueue.main.async { sizer.updateContentSize(size) }
        }
        .onChange(of: isLargeDisplay) { large in
            sizer.usePreset(scale: large ? 2 : 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) { notification in
            if let window = notification.object as? NSWindow, window === sizer.window {
                updateScreenLimit()
            }
        }
    }

    private func updateScreenLimit() {
        if let window = sizer.window, let screen = window.screen {
            maximumContentHeight = screen.visibleFrame.height - (window.frame.height - window.contentLayoutRect.height)
        }
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowTrackingView {
        WindowTrackingView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
        nsView.onResolve = onResolve
    }

    final class WindowTrackingView: NSView {
        var onResolve: @MainActor (NSWindow?) -> Void

        init(onResolve: @escaping @MainActor (NSWindow?) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                onResolve(window)
            }
        }
    }
}

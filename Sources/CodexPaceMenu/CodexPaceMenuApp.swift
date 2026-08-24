import AppKit
import CodexPaceUI
import SwiftUI

private enum PaceWindow {
    static let id = "pace-window"
}

@main
struct CodexPaceMenuApp: App {
    @StateObject private var model = PaceViewModel()
    @AppStorage("largeDisplayEnabled") private var isLargeDisplay = false

    var body: some Scene {
        Window("Codex Pace", id: PaceWindow.id) {
            MainWindowContent(model: model, isLargeDisplay: $isLargeDisplay)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Text(model.menuBarText)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MainWindowContent: View {
    @ObservedObject var model: PaceViewModel
    @Binding var isLargeDisplay: Bool
    @StateObject private var resizeCoordinator = WindowResizeCoordinator()

    var body: some View {
        PaceMenuView(
            model: model,
            isLargeDisplay: displaySizeBinding
        )
        .background {
            WindowAccessor { window in
                resizeCoordinator.window = window
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) {
            notification in
            resizeCoordinator.windowDidResize(notification.object as? NSWindow)
        }
    }

    private var displaySizeBinding: Binding<Bool> {
        Binding(
            get: { isLargeDisplay },
            set: { newValue in
                resizeCoordinator.setLargeDisplay(
                    newValue,
                    isLargeDisplay: $isLargeDisplay
                )
            }
        )
    }
}

@MainActor
private final class WindowResizeCoordinator: ObservableObject {
    weak var window: NSWindow?
    private var pendingResize: PendingResize?

    func setLargeDisplay(_ newValue: Bool, isLargeDisplay: Binding<Bool>) {
        guard newValue != isLargeDisplay.wrappedValue else {
            return
        }

        if
            let window,
            let visibleFrame = window.screen?.visibleFrame
        {
            pendingResize = PendingResize(
                previousFrame: window.frame,
                visibleFrame: visibleFrame,
                preservesRightEdge: !newValue
            )
        } else {
            pendingResize = nil
        }

        isLargeDisplay.wrappedValue = newValue
    }

    func windowDidResize(_ resizedWindow: NSWindow?) {
        guard
            let resizedWindow,
            resizedWindow === window,
            let pendingResize,
            resizedWindow.frame.size != pendingResize.previousFrame.size
        else {
            return
        }

        self.pendingResize = nil
        let adjustedFrame = WindowFramePlacement.frameKeepingResizeVisible(
            resizedFrame: resizedWindow.frame,
            previousFrame: pendingResize.previousFrame,
            visibleFrame: pendingResize.visibleFrame,
            preservesRightEdge: pendingResize.preservesRightEdge
        )
        if adjustedFrame.origin != resizedWindow.frame.origin {
            resizedWindow.setFrameOrigin(adjustedFrame.origin)
        }
    }

    private struct PendingResize {
        let previousFrame: CGRect
        let visibleFrame: CGRect
        let preservesRightEdge: Bool
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PaceMenuView(model: model) {
            openWindow(id: PaceWindow.id)
            dismiss()
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}

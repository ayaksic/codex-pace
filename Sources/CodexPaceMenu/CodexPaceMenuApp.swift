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
    @StateObject private var resizeCoordinator = PaceWindowSizer()
    @State private var maximumContentHeight = (NSScreen.main?.visibleFrame.height ?? 800) - 40

    var body: some View {
        PaceMenuView(
            model: model,
            isLargeDisplay: $isLargeDisplay,
            maximumHeight: maximumContentHeight
        )
        .background {
            WindowAccessor { window in
                resizeCoordinator.window = window
                if let window, let screen = window.screen {
                    maximumContentHeight = screen.visibleFrame.height - (window.frame.height - window.contentLayoutRect.height)
                }
            }
        }
        .onPreferenceChange(PaceContentSizeKey.self) { size in
            DispatchQueue.main.async {
                resizeCoordinator.updateContentSize(size)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) { notification in
            if let window = notification.object as? NSWindow,
               window === resizeCoordinator.window, let screen = window.screen {
                maximumContentHeight = screen.visibleFrame.height - (window.frame.height - window.contentLayoutRect.height)
            }
        }
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

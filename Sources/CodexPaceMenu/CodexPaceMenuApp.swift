import AppKit
import CodexPaceUI
import SwiftUI

private enum PaceWindow {
    static let id = "pace-window"
    static let mainValue = "main"
}

@main
struct CodexPaceMenuApp: App {
    @StateObject private var model = PaceViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Text(model.menuBarText)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Codex Pace", id: PaceWindow.id, for: String.self) { _ in
            PaceMenuView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PaceMenuView(model: model) {
            openWindow(
                id: PaceWindow.id,
                value: PaceWindow.mainValue
            )
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}

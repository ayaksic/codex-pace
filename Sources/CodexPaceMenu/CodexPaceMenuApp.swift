import AppKit
import CodexPaceUI
import SwiftUI

private enum PaceWindow {
    static let id = "pace-window"
}

@main
struct CodexPaceMenuApp: App {
    @StateObject private var model = PaceViewModel()

    var body: some Scene {
        Window("Codex Pace", id: PaceWindow.id) {
            PaceMenuView(model: model)
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

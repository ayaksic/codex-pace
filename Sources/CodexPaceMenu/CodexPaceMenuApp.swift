import CodexPaceUI
import SwiftUI

@main
struct CodexPaceMenuApp: App {
    @StateObject private var model = PaceViewModel()

    var body: some Scene {
        MenuBarExtra {
            PaceMenuView(model: model)
        } label: {
            Text(model.menuBarText)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}

import CodexPaceUI
import SwiftUI

@main
struct CodexPaceMenuApp: App {
    @StateObject private var model = PaceViewModel()

    var body: some Scene {
        MenuBarExtra {
            PaceMenuView(model: model)
        } label: {
            Label(model.menuBarText, systemImage: "gauge.with.dots.needle.67percent")
        }
        .menuBarExtraStyle(.window)
    }
}

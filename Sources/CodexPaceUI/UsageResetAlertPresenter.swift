import AppKit
import SwiftUI

/// Independent of the main and credit-warning windows, so refreshes keep running.
@MainActor
final class UsageResetAlertPresenter {
    static let shared = UsageResetAlertPresenter()
    private var panel: NSPanel?

    func show() {
        if panel == nil { panel = makePanel() }
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Codex Pace"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        let content = NSHostingView(rootView: UsageResetAlertView { [weak panel] in
            panel?.close()
        })
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        panel.center()
        return panel
    }
}

public struct UsageResetAlertView: View {
    private let dismiss: () -> Void

    public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly usage reset to 100%")
                .font(.headline)
            Text("Codex reports that your full weekly usage allowance is available again.")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("OK", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

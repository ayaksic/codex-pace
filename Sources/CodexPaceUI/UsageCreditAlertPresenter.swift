import AppKit
import SwiftUI

/// A separate window keeps the warning visible even when the main window is closed.
/// It does not block the refresh timer while waiting for dismissal.
@MainActor
final class UsageCreditAlertPresenter {
    static let shared = UsageCreditAlertPresenter()
    private var panel: NSPanel?
    private var snooze: (() -> Void)?

    func show(snooze: @escaping () -> Void) {
        self.snooze = snooze
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
        let content = NSHostingView(rootView: UsageCreditConsumptionAlertView(
            dismiss: { [weak panel] in panel?.close() },
            snooze: { [weak self, weak panel] in
                self?.snooze?()
                panel?.close()
            }
        ))
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        panel.center()
        return panel
    }
}

public struct UsageCreditConsumptionAlertView: View {
    private let dismiss: () -> Void
    private let snooze: () -> Void

    public init(dismiss: @escaping () -> Void, snooze: @escaping () -> Void) {
        self.dismiss = dismiss
        self.snooze = snooze
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Included Codex usage exhausted")
                .font(.headline)
            Text("Codex reports that included usage is unavailable, and your usage-credit balance has decreased. Continued work can consume additional usage credits.")
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer()
                Button("Snooze for 30 minutes", action: snooze)
                Button("OK", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

import AppKit
import Foundation
import SwiftUI

public struct BankedResetExpiryWarning: Equatable, Sendable {
    public let creditID: String
    public let expiresAt: Date
    public let hoursRemaining: Int
    public let availabilityIsLastKnown: Bool

    public init(creditID: String, expiresAt: Date, hoursRemaining: Int, availabilityIsLastKnown: Bool = false) {
        self.creditID = creditID
        self.expiresAt = expiresAt
        self.hoursRemaining = hoursRemaining
        self.availabilityIsLastKnown = availabilityIsLastKnown
    }
}

/// Expiry-relative hour buckets prevent refreshes or relaunches from repeating a warning.
@MainActor
struct BankedResetReminderHistory {
    private struct Receipt: Codable, Equatable {
        let accountID: String?
        let creditID: String
        let expiresAt: Date
        var smallestHour: Int
    }

    private static let key = "bankedResetExpiryReminders"
    private let defaults: UserDefaults
    private var receipts: [Receipt]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        receipts = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Receipt].self, from: $0) } ?? []
    }

    mutating func recordDue(_ warnings: [BankedResetExpiryWarning], accountID: String?, now: Date) -> Bool {
        let previous = receipts
        receipts.removeAll { $0.expiresAt <= now }
        let accountID = accountID.flatMap { $0.isEmpty ? nil : $0 }
        var due = false
        for warning in warnings {
            if let index = receipts.firstIndex(where: {
                $0.accountID == accountID && $0.creditID == warning.creditID && $0.expiresAt == warning.expiresAt
            }) {
                guard warning.hoursRemaining < receipts[index].smallestHour else { continue }
                receipts[index].smallestHour = warning.hoursRemaining
            } else {
                receipts.append(Receipt(accountID: accountID, creditID: warning.creditID,
                                        expiresAt: warning.expiresAt, smallestHour: warning.hoursRemaining))
            }
            due = true
        }
        if receipts != previous,
           let data = try? JSONEncoder().encode(receipts.filter { $0.accountID != nil }) {
            defaults.set(data, forKey: Self.key)
        }
        return due
    }
}

/// One persistent, nonmodal warning window groups simultaneous expirations.
@MainActor
final class BankedResetExpiryAlertPresenter: NSObject, NSWindowDelegate {
    static let shared = BankedResetExpiryAlertPresenter()
    private var panel: NSPanel?
    private var warnings: [BankedResetExpiryWarning] = []
    private var attentionRequest: Int?

    func update(_ warnings: [BankedResetExpiryWarning], shouldPresent: Bool) {
        if warnings.isEmpty {
            panel?.close()
            self.warnings = []
            return
        }
        guard shouldPresent || panel?.isVisible == true else { return }
        if panel == nil { panel = makePanel() }
        if self.warnings != warnings {
            self.warnings = warnings
            let content = NSHostingView(rootView: BankedResetExpiryAlertView(warnings: warnings) { [weak self] in
                self?.panel?.close()
            })
            panel?.contentView = content
            panel?.setContentSize(content.fittingSize)
        }
        guard shouldPresent else { return }
        cancelAttention()
        NSSound.beep()
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        attentionRequest = NSApplication.shared.requestUserAttention(.criticalRequest)
    }

    func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 240),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Banked reset expires soon"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.center()
        return panel
    }

    func windowWillClose(_ notification: Notification) { cancelAttention() }

    private func cancelAttention() {
        if let attentionRequest {
            NSApplication.shared.cancelUserAttentionRequest(attentionRequest)
            self.attentionRequest = nil
        }
    }
}

public struct BankedResetExpiryAlertView: View {
    let warnings: [BankedResetExpiryWarning]
    let dismiss: () -> Void

    public init(warnings: [BankedResetExpiryWarning], dismiss: @escaping () -> Void) {
        self.warnings = warnings
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Banked reset expires soon", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Use your banked reset in Codex before it expires. This warning does not apply the reset for you.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(warnings.indices, id: \.self) { index in
                    let warning = warnings[index]
                    Text("Expires within \(warning.hoursRemaining) \(warning.hoursRemaining == 1 ? "hour" : "hours") • \(warning.expiresAt.formatted(date: .abbreviated, time: .standard))")
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if warnings.contains(where: \.availabilityIsLastKnown) {
                Text("Availability is last confirmed. Codex Pace could not refresh it; check Codex to see whether the reset is still available.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Warnings repeat hourly during the final 12 hours while Codex Pace is running and your Mac is awake.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Acknowledge", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

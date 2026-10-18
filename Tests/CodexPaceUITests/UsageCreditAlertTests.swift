import AppKit
import CodexPaceCore
import Foundation
import SwiftUI
import Testing
@testable import CodexPaceUI

private let alertFixtureDate = Date(timeIntervalSince1970: 2_000_000_000)

private func creditReading(
    balance: String? = "100",
    allowed: Bool? = false,
    used: Double = 100,
    account: String? = "fixture-account",
    offset: TimeInterval = 0,
    resetOffset: TimeInterval = 3_600
) -> PaceSnapshot {
    PaceSnapshot(
        weeklyWindow: UsageWindow(usedPercent: used, durationMinutes: 10_080,
                                  resetsAt: alertFixtureDate.addingTimeInterval(resetOffset)),
        fetchedAt: alertFixtureDate.addingTimeInterval(offset),
        creditBalance: balance,
        ordinaryUsageAllowed: allowed,
        accountID: account
    )
}

@MainActor
@Test func alertsOnceForConfirmedCreditConsumptionAndRearmsOnExplicitRecovery() {
    let suiteName = "UsageCreditAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    var alerts = 0
    let model = PaceViewModel(snapshot: creditReading(), pollingEnabled: false,
                              defaults: defaults, creditConsumptionAlert: { alerts += 1 })
    model.applyFreshSnapshot(creditReading(balance: "99.999", offset: 15))
    #expect(alerts == 1)
    model.applyFreshSnapshot(creditReading(balance: "99.998", offset: 30))
    #expect(alerts == 1)

    let relaunched = PaceViewModel(snapshot: creditReading(balance: "99.998", offset: 30),
                                   pollingEnabled: false, defaults: defaults,
                                   creditConsumptionAlert: { alerts += 1 }, usageResetAlert: {})
    relaunched.applyFreshSnapshot(creditReading(balance: "99.997", offset: 45))
    #expect(alerts == 1)
    // Rounded percentages and missing permission must not infer recovery.
    relaunched.applyFreshSnapshot(creditReading(balance: "99.997", allowed: nil, used: 99, offset: 60))
    relaunched.applyFreshSnapshot(creditReading(balance: "99.996", offset: 75))
    #expect(alerts == 1)
    relaunched.applyFreshSnapshot(creditReading(balance: "99.996", allowed: true, used: 0, offset: 90))
    relaunched.applyFreshSnapshot(creditReading(balance: "99.995", offset: 105))
    #expect(alerts == 2)

    // A genuinely new weekly window permits a new warning.
    relaunched.applyFreshSnapshot(creditReading(balance: "99.995", offset: 120, resetOffset: 7 * 86_400))
    relaunched.applyFreshSnapshot(creditReading(balance: "99.994", offset: 135, resetOffset: 7 * 86_400))
    #expect(alerts == 3)
}

@MainActor
@Test func doesNotMistakeRoundedZeroMissingDataOrAccountChangesForCreditConsumption() {
    let suiteName = "UsageCreditAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let candidates = [
        creditReading(balance: "99", allowed: nil, offset: 15),
        creditReading(balance: "99", allowed: true, offset: 15),
        creditReading(balance: "99", used: 99.6, offset: 15),
        creditReading(balance: "100", offset: 15),
        creditReading(balance: "101", offset: 15),
        creditReading(balance: nil, offset: 15),
        creditReading(balance: "garbage", offset: 15),
        creditReading(balance: "NaN", offset: 15),
        creditReading(balance: "99", account: nil, offset: 15),
        creditReading(balance: "99", account: "different-account", offset: 15),
        creditReading(balance: "99", offset: 0),
        creditReading(balance: "99", offset: -15),
        creditReading(balance: "99", offset: 15, resetOffset: 7 * 86_400),
        creditReading(balance: "99", offset: 3_601),
    ]
    for candidate in candidates {
        var alerts = 0
        let model = PaceViewModel(snapshot: creditReading(), pollingEnabled: false,
                                  defaults: defaults, creditConsumptionAlert: { alerts += 1 })
        model.applyFreshSnapshot(candidate)
        #expect(alerts == 0)
    }
    for priorBalance in [nil, "invalid"] as [String?] {
        var alerts = 0
        let model = PaceViewModel(snapshot: creditReading(balance: priorBalance), pollingEnabled: false,
                                  defaults: defaults, creditConsumptionAlert: { alerts += 1 })
        model.applyFreshSnapshot(creditReading(balance: "99", offset: 15))
        #expect(alerts == 0)
    }
    // Preserve valid signed balances rather than declaring a reported debt invalid.
    var signedBalanceAlerts = 0
    let signedModel = PaceViewModel(snapshot: creditReading(balance: "0"), pollingEnabled: false,
                                    defaults: defaults, creditConsumptionAlert: { signedBalanceAlerts += 1 })
    signedModel.applyFreshSnapshot(creditReading(balance: "-0.001", offset: 15))
    #expect(signedBalanceAlerts == 1)
}

@MainActor
@Test func creditAlertHistorySurvivesSwitchingBetweenAccounts() {
    let suiteName = "UsageCreditAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    var alerts = 0
    let model = PaceViewModel(pollingEnabled: false, defaults: defaults,
                              creditConsumptionAlert: { alerts += 1 })
    for (index, account) in ["fixture-a", "fixture-b", "fixture-a", "fixture-b"].enumerated() {
        let offset = Double(index) * 30
        model.applyFreshSnapshot(creditReading(account: account, offset: offset))
        model.applyFreshSnapshot(creditReading(balance: "99", account: account, offset: offset + 15))
    }
    #expect(alerts == 2)
}

@MainActor
@Test func creditAlertCreatesAnIndependentWindowWithEqualPeerSpacing() throws {
    _ = NSApplication.shared
    let panel = UsageCreditAlertPresenter().makePanel()
    defer { panel.close() }
    #expect(panel.title == "Codex Pace")
    #expect(panel.level == .floating)
    #expect(panel.styleMask.contains(.closable))
    #expect(panel.contentView?.frame.width == 420)
    #expect((panel.contentView?.frame.height ?? 0) > 100)
    panel.makeKeyAndOrderFront(nil)
    #expect(panel.isVisible)
    #expect(NSApplication.shared.modalWindow == nil)
    let renderer = ImageRenderer(content: UsageCreditConsumptionAlertView(dismiss: {}))
    let image = try #require(renderer.nsImage)
    #expect(image.size.width == 420)
    #expect(image.size.height == panel.contentView?.frame.height)
    // Adjacent title, message and actions use one parent-controlled stack gap.
    let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/CodexPaceUI/UsageCreditAlertPresenter.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source.contains("VStack(alignment: .leading, spacing: 16)"))
    #expect(!source.contains(".padding(.top"))
    #expect(!source.contains(".padding(.bottom"))
}

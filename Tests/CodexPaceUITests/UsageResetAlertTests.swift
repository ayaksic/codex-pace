import AppKit
import CodexPaceCore
import Foundation
import Testing
@testable import CodexPaceUI

private let resetFixtureDate = Date(timeIntervalSince1970: 2_000_000_000)

private func resetReading(
    used: Double,
    offset: TimeInterval,
    account: String? = "fixture-account",
    resetOffset: TimeInterval = 7 * 86_400
) -> PaceSnapshot {
    PaceSnapshot(
        weeklyWindow: UsageWindow(usedPercent: used, durationMinutes: 10_080,
                                  resetsAt: resetFixtureDate.addingTimeInterval(resetOffset)),
        fetchedAt: resetFixtureDate.addingTimeInterval(offset),
        accountID: account
    )
}

@MainActor
@Test func alertsForEachFullResetWithoutRepeatingWhileFull() {
    let suite = "UsageResetAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var alerts = 0
    let model = PaceViewModel(pollingEnabled: false, defaults: defaults,
                              usageResetAlert: { alerts += 1 })
    model.applyFreshSnapshot(resetReading(used: 0, offset: 0))
    model.applyFreshSnapshot(resetReading(used: 0, offset: 15))
    #expect(alerts == 0) // Starting full is not a reset.
    model.applyFreshSnapshot(resetReading(used: 70, offset: 30))
    model.applyFreshSnapshot(resetReading(used: 0.4, offset: 45))
    #expect(alerts == 0) // Rounded 100% is not exactly full.
    model.applyFreshSnapshot(resetReading(used: 0, offset: 60))
    model.applyFreshSnapshot(resetReading(used: 0, offset: 75))
    #expect(alerts == 1)
    // Stale readings must not rearm the alert, including across relaunches.
    model.applyFreshSnapshot(resetReading(used: 50, offset: 45))
    model.applyFreshSnapshot(resetReading(used: 0, offset: 90))
    #expect(alerts == 1)
    model.applyFreshSnapshot(resetReading(used: 100, offset: 105))
    model.applyFreshSnapshot(resetReading(used: 0, offset: 120, resetOffset: 14 * 86_400))
    #expect(alerts == 2) // Both an early reset and a new weekly window qualify.
}

@MainActor
@Test func resetDetectionAndDuplicateSuppressionSurviveRelaunchPerAccount() {
    let suite = "UsageResetAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var alerts = 0
    let original = PaceViewModel(pollingEnabled: false, defaults: defaults,
                                 usageResetAlert: { alerts += 1 })
    original.applyFreshSnapshot(resetReading(used: 100, offset: 0))
    let relaunched = PaceViewModel(pollingEnabled: false, defaults: defaults,
                                   usageResetAlert: { alerts += 1 })
    relaunched.applyFreshSnapshot(resetReading(used: 0, offset: 60))
    #expect(alerts == 1)
    let again = PaceViewModel(pollingEnabled: false, defaults: defaults,
                              usageResetAlert: { alerts += 1 })
    again.applyFreshSnapshot(resetReading(used: 0, offset: 120))
    again.applyFreshSnapshot(resetReading(used: 80, offset: 135))
    again.applyFreshSnapshot(resetReading(used: 0, offset: 150, account: "fixture-b"))
    #expect(alerts == 1) // Another account's full reading is not a reset.
    again.applyFreshSnapshot(resetReading(used: 0, offset: 165))
    #expect(alerts == 2) // Returning to the first account uses its own baseline.
}

@MainActor
@Test func invalidStaleAndEstimatedResetsDoNotTriggerAlerts() {
    let suite = "UsageResetAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var alerts = 0
    let model = PaceViewModel(snapshot: resetReading(used: 100, offset: 0),
                              now: resetFixtureDate, pollingEnabled: false, defaults: defaults,
                              usageResetAlert: { alerts += 1 })
    model.setManualResetAt(resetFixtureDate.addingTimeInterval(30))
    model.applyFreshSnapshot(resetReading(used: 100, offset: 60),
                             now: resetFixtureDate.addingTimeInterval(60))
    for reading in [
        resetReading(used: 0, offset: 0),
        resetReading(used: 0, offset: 60),
        resetReading(used: -1, offset: 75),
        resetReading(used: .nan, offset: 90),
        resetReading(used: .infinity, offset: 105),
        resetReading(used: 0, offset: 120, resetOffset: 100),
    ] {
        model.applyFreshSnapshot(reading)
        #expect(alerts == 0)
    }
    model.applyFreshSnapshot(resetReading(used: 0, offset: 135))
    #expect(alerts == 1)
}

@MainActor
@Test func anonymousResetDetectionUsesOnlyCurrentSessionAndIgnoresStaleReadings() {
    let suite = "UsageResetAlertTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var alerts = 0
    let model = PaceViewModel(pollingEnabled: false, defaults: defaults,
                              usageResetAlert: { alerts += 1 })
    for (used, offset) in [(50.0, 0.0), (0, 15), (40, 0), (0, 30)] {
        model.applyFreshSnapshot(resetReading(used: used, offset: offset, account: nil))
    }
    #expect(alerts == 1)
    let relaunched = PaceViewModel(pollingEnabled: false, defaults: defaults,
                                   usageResetAlert: { alerts += 1 })
    relaunched.applyFreshSnapshot(resetReading(used: 0, offset: 45, account: nil))
    #expect(alerts == 1)
}

@MainActor
@Test func resetAlertUsesAnIndependentNonblockingWindowAndEqualPeerGaps() throws {
    _ = NSApplication.shared
    let panel = UsageResetAlertPresenter().makePanel()
    defer { panel.close() }
    #expect(panel.level == .floating)
    #expect(panel.styleMask.contains(.closable))
    #expect(panel.contentView?.frame.width == 420)
    panel.makeKeyAndOrderFront(nil)
    #expect(panel.isVisible)
    #expect(NSApplication.shared.modalWindow == nil)
    panel.close()
    #expect(!panel.isVisible)
    panel.makeKeyAndOrderFront(nil)
    #expect(panel.isVisible) // The retained panel can display the next reset.
    let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/CodexPaceUI/UsageResetAlertPresenter.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source.contains("VStack(alignment: .leading, spacing: 16)"))
    #expect(!source.contains(".padding(.top"))
    #expect(!source.contains(".padding(.bottom"))
}

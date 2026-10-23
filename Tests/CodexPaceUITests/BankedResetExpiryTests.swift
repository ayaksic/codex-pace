import AppKit
import CodexPaceCore
import Foundation
import SwiftUI
import Testing
@testable import CodexPaceUI

private let expiryFixtureNow = Date(timeIntervalSince1970: 2_000_000_000)

private func credit(_ id: String = "reset-a", expires: Date?, status: String = "available",
                    type: String = "codexRateLimits") -> RateLimitResetCredit {
    RateLimitResetCredit(id: id, resetType: type, status: status,
                        grantedAt: expiryFixtureNow.addingTimeInterval(-86_400), expiresAt: expires)
}

private func reading(at now: Date, credits: [RateLimitResetCredit], used: Double = 0,
                     account: String? = "fixture-account") -> PaceSnapshot {
    PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: used, durationMinutes: 10_080,
                                          resetsAt: expiryFixtureNow.addingTimeInterval(7 * 86_400)),
                 fetchedAt: now, rateLimitResetCredits: RateLimitResetCredits(
                    availableCount: credits.filter { $0.status == "available" }.count, credits: credits),
                 accountID: account)
}

@MainActor
private final class ExpiryHarness {
    let suite = "BankedResetExpiryTests.\(UUID())"
    let defaults: UserDefaults
    var alerts: [[BankedResetExpiryWarning]] = []
    var visibleWarnings: [BankedResetExpiryWarning] = []

    init() { defaults = UserDefaults(suiteName: suite)! }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }

    func model(snapshot: PaceSnapshot? = nil, now: Date = expiryFixtureNow) -> PaceViewModel {
        PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false, defaults: defaults,
                      creditConsumptionAlert: {}, usageResetAlert: {}, bankedResetWarning: { warnings, present in
            self.visibleWarnings = warnings
            if present { self.alerts.append(warnings) }
        })
    }
}

@MainActor @Test
func bankedDeadlineDrivesPercentPaceTimingAndBothBarInputsTogether() throws {
    let h = ExpiryHarness()
    defer { h.cleanUp() }
    let expiry = expiryFixtureNow.addingTimeInterval(6 * 86_400 + 4_600)
    let model = h.model(snapshot: reading(at: expiryFixtureNow, credits: [credit(expires: expiry)]))
    let window = try #require(model.effectiveWeeklyWindow)
    #expect(model.resetCountdownTarget == ResetCountdownTarget(date: expiry, kind: .bankedResetExpiry))
    #expect(window.resetsAt == expiry)
    #expect(window.durationMinutes == 10_080)
    let expectedTime = (6 * 86_400.0 + 4_600) / (7 * 86_400) * 100
    #expect(abs(window.timeRemainingPercent(at: model.now) - expectedTime) < 0.0001)
    #expect(model.menuBarText == "86.5% / 100%")
    #expect(model.timeRemainingLabel == "To expiry")
    #expect(model.timelineLabel == "Expiry")
    #expect(model.timelineDescription.contains("banked reset expiration"))
    #expect(abs(try #require(model.currentPaceDelta) - (100 - expectedTime)) < 0.0001)
    #expect(model.paceText == "Speed up (+13.5%)")
    #expect(model.paceTimeFields == DurationFields(hours: 22, minutes: 43, seconds: 20))
    let timeline = WeeklyTimelineProgress(window: window, at: model.now)
    #expect(abs(timeline.elapsedFraction - (1 - expectedTime / 100)) < 0.0001)
    #expect(timeline.usageUsedFraction == 0)

    let earlierEstimate = expiryFixtureNow.addingTimeInterval(3_600)
    model.setManualResetAt(earlierEstimate)
    #expect(model.effectiveWeeklyWindow?.resetsAt == earlierEstimate)
    #expect(model.timeRemainingLabel == "To estimate")
    model.setManualResetAt(expiry.addingTimeInterval(3_600))
    #expect(model.effectiveWeeklyWindow?.resetsAt == expiry)
    #expect(model.timeRemainingLabel == "To expiry")
    model.clearManualReset()
    model.applyFreshSnapshot(reading(at: expiryFixtureNow, credits: [credit(expires: expiry, status: "consumed")]),
                             now: expiryFixtureNow)
    #expect(model.effectiveWeeklyWindow?.resetsAt == model.snapshot?.weeklyWindow.resetsAt)
    #expect(model.timeRemainingLabel == "Week left")
    #expect(model.menuBarText == "100.0% / 100%")
}

@MainActor @Test
func expiryPacingFallsBackToNextCreditThenNaturalResetAndRecalculatesStoppage() {
    let h = ExpiryHarness()
    defer { h.cleanUp() }
    let first = expiryFixtureNow.addingTimeInterval(86_400)
    let second = expiryFixtureNow.addingTimeInterval(2 * 86_400)
    let credits = [credit("first", expires: first), credit("second", expires: second)]
    let model = h.model(snapshot: reading(at: expiryFixtureNow, credits: credits, used: 90))
    #expect(model.paceMetricLabel == "Slow down")
    #expect(model.stoppageEndsAt == expiryFixtureNow.addingTimeInterval(25_920))
    #expect(model.paceTimeFields == DurationFields(hours: 7, minutes: 12, seconds: 0))
    model.applyFreshSnapshot(reading(at: first, credits: credits, used: 90), now: first)
    #expect(model.effectiveWeeklyWindow?.resetsAt == second)
    model.applyFreshSnapshot(reading(at: second, credits: credits, used: 90), now: second)
    #expect(model.effectiveWeeklyWindow?.resetsAt == model.snapshot?.weeklyWindow.resetsAt)
}

@MainActor @Test
func hourlyWarningsCoverAllTwelveBoundariesWithoutRefreshOrRelaunchDuplicates() {
    let h = ExpiryHarness()
    defer { h.cleanUp() }
    let expires = expiryFixtureNow.addingTimeInterval(12 * 3_600)
    let credits = [credit(expires: expires)]
    var model = h.model()
    model.applyFreshSnapshot(reading(at: expiryFixtureNow.addingTimeInterval(-1), credits: credits),
                             now: expiryFixtureNow.addingTimeInterval(-1))
    #expect(h.alerts.isEmpty)
    for hour in stride(from: 12, through: 1, by: -1) {
        let now = expires.addingTimeInterval(-Double(hour) * 3_600)
        let snapshot = reading(at: now, credits: credits)
        model.applyFreshSnapshot(snapshot, now: now)
        model.checkBankedResetReminders()
        model = h.model(snapshot: snapshot, now: now)
        model.checkBankedResetReminders()
        #expect(h.alerts.count == 13 - hour)
        #expect(h.alerts.last?.first?.hoursRemaining == hour)
    }
    model.applyFreshSnapshot(reading(at: expires, credits: credits), now: expires)
    #expect(h.alerts.count == 12)
    #expect(h.visibleWarnings.isEmpty)
}

@MainActor @Test
func warningsGroupCreditsAndMarkStaleAvailabilityAfterSleepWithoutReplayingMissedHours() {
    let h = ExpiryHarness()
    defer { h.cleanUp() }
    let expires = expiryFixtureNow.addingTimeInterval(12 * 3_600)
    let credits = [credit("a", expires: expires), credit("b", expires: expires)]
    let initial = reading(at: expiryFixtureNow, credits: credits)
    let model = h.model(snapshot: initial, now: expiryFixtureNow.addingTimeInterval(8 * 3_600))
    model.checkBankedResetReminders()
    #expect(h.alerts.count == 1)
    #expect(h.alerts[0].allSatisfy { $0.availabilityIsLastKnown })
    let wake = expiryFixtureNow.addingTimeInterval(8 * 3_600)
    model.applyFreshSnapshot(reading(at: wake, credits: credits), now: wake)
    #expect(h.alerts.count == 1)
    #expect(h.alerts[0].map(\.creditID) == ["a", "b"])
    #expect(h.alerts[0].allSatisfy { $0.hoursRemaining == 4 })
    #expect(h.visibleWarnings.allSatisfy { !$0.availabilityIsLastKnown })
    model.applyFreshSnapshot(reading(at: wake, credits: [credit("b", expires: expires)]), now: wake)
    #expect(h.alerts.count == 1)
    #expect(h.visibleWarnings.map(\.creditID) == ["b"])
    model.applyFreshSnapshot(reading(at: wake, credits: []), now: wake)
    #expect(h.visibleWarnings.isEmpty)
    model.applyFreshSnapshot(initial, now: wake)
    #expect(h.visibleWarnings.isEmpty) // An older reading cannot resurrect a used credit.
}

@MainActor @Test
func warningsExcludeUnknownExpiredConsumedAndOtherCreditTypesAndIsolateAccounts() {
    let h = ExpiryHarness()
    defer { h.cleanUp() }
    let expires = expiryFixtureNow.addingTimeInterval(3_600)
    let invalid = [credit("unknown", expires: nil), credit("expired", expires: expiryFixtureNow),
                   credit("used", expires: expires, status: "consumed"),
                   credit("other", expires: expires, type: "other"),
                   credit("later", expires: expiryFixtureNow.addingTimeInterval(12 * 3_600 + 1))]
    let model = h.model()
    model.applyFreshSnapshot(reading(at: expiryFixtureNow, credits: invalid), now: expiryFixtureNow)
    #expect(h.alerts.isEmpty)
    for account in ["a", "b", "a", "b"] {
        model.applyFreshSnapshot(reading(at: expiryFixtureNow, credits: [credit(expires: expires)], account: account),
                                 now: expiryFixtureNow)
    }
    #expect(h.alerts.count == 2)
    // A reissued credit with a new expiration has its own warning history.
    model.applyFreshSnapshot(reading(at: expiryFixtureNow, credits: [credit(expires: expires.addingTimeInterval(60))],
                                     account: "b"), now: expiryFixtureNow)
    #expect(h.alerts.count == 3)
}

@MainActor @Test
func expiryWarningWindowIsPersistentNonblockingAndUsesEqualPeerGaps() throws {
    _ = NSApplication.shared
    let presenter = BankedResetExpiryAlertPresenter()
    let panel = presenter.makePanel()
    defer { panel.close() }
    #expect(panel.level == .floating)
    #expect(!panel.hidesOnDeactivate)
    #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(panel.styleMask.contains(.closable))
    panel.makeKeyAndOrderFront(nil)
    #expect(panel.isVisible)
    #expect(NSApplication.shared.modalWindow == nil)
    let warnings = [BankedResetExpiryWarning(creditID: "a", expiresAt: expiryFixtureNow, hoursRemaining: 1)]
    let image = try #require(ImageRenderer(content: BankedResetExpiryAlertView(warnings: warnings, dismiss: {})).nsImage)
    #expect(image.size.width == 440)
    let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/CodexPaceUI/BankedResetExpiryAlertPresenter.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source.contains("VStack(alignment: .leading, spacing: 16)"))
    #expect(!source.contains(".padding(.top"))
    #expect(!source.contains(".padding(.bottom"))
}

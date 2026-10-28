import Foundation
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@MainActor private final class ResetRowHarness {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let suite = "ResetRowVisibilityTests.\(UUID())"
    let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: suite)! }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }

    func model(bankedExpiry: Date? = nil, usedPercent: Double = 26) -> PaceViewModel {
        let credits = bankedExpiry.map { expiry in
            RateLimitResetCredits(availableCount: 1, credits: [
                RateLimitResetCredit(id: "visibility-fixture", resetType: "codexRateLimits",
                    status: "available", grantedAt: now, expiresAt: expiry)
            ])
        }
        let snapshot = PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: usedPercent,
            durationMinutes: 10_080, resetsAt: now.addingTimeInterval(6 * 86_400)),
            fetchedAt: now, rateLimitResetCredits: credits)
        return PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false, defaults: defaults,
            creditConsumptionAlert: {}, usageResetAlert: {}, bankedResetWarning: { _, _ in })
    }
}

@Test @MainActor func activeEstimateReplacesTheReportedResetRowUntilRemoved() {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model()
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.natural])
    let estimate = h.now.addingTimeInterval(3_600)
    model.setManualResetAt(estimate)
    #expect(model.visibleResetCountdownTargets == [ResetCountdownTarget(date: estimate, kind: .manualEstimate)])
    #expect(model.effectiveWeeklyWindow?.resetsAt == estimate)
    model.clearManualReset()
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.natural])
}

@Test @MainActor func anEstimateHidesTheReportedRowEvenWhenBankedExpiryIsEarlier() {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let expiry = h.now.addingTimeInterval(86_400)
    let model = h.model(bankedExpiry: expiry)
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.bankedResetExpiry, .natural])
    model.setManualResetAt(h.now.addingTimeInterval(2 * 86_400))
    #expect(model.resetCountdownTarget?.kind == .bankedResetExpiry)
    #expect(model.visibleResetCountdownTargets == [ResetCountdownTarget(date: expiry, kind: .bankedResetExpiry)])
    #expect(model.effectiveWeeklyWindow?.resetsAt == expiry)
    model.clearManualReset()
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.bankedResetExpiry, .natural])
}

@Test @MainActor func anExpiredEstimateRestoresTheReportedResetRow() throws {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model()
    let estimate = h.now.addingTimeInterval(3_600)
    model.setManualResetAt(estimate)
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.manualEstimate])
    model.applyFreshSnapshot(try #require(model.snapshot), now: estimate)
    #expect(!model.isManualResetActive)
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.natural])
}

@Test @MainActor func aLaterEstimateHidesTheReportedRowWithoutChangingThePacingTarget() {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model()
    let natural = model.resetCountdownTarget
    model.setManualResetAt(h.now.addingTimeInterval(8 * 86_400))
    #expect(model.isManualResetActive)
    #expect(model.resetCountdownTarget == natural)
    #expect(model.visibleResetCountdownTargets.isEmpty)
    model.clearManualReset()
    #expect(model.visibleResetCountdownTargets == [natural!])
}

@Test @MainActor func timeAheadIsHiddenOnlyWhileTheEstimateRowIsVisible() throws {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model(usedPercent: 0)
    #expect(model.visiblePaceTimeLabel == "Time ahead")
    let estimate = h.now.addingTimeInterval(3_600)
    model.setManualResetAt(estimate)
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.manualEstimate])
    #expect(model.visiblePaceTimeLabel == nil)
    #expect(model.paceTimeLabel == "Time ahead")
    #expect(model.paceTimeFields != nil)
    model.clearManualReset()
    #expect(model.visiblePaceTimeLabel == "Time ahead")
    model.setManualResetAt(estimate)
    model.applyFreshSnapshot(try #require(model.snapshot), now: estimate)
    #expect(model.visiblePaceTimeLabel == "Time ahead")

    // An active estimate can be hidden behind an earlier banked or natural reset.
    let banked = h.model(bankedExpiry: h.now.addingTimeInterval(3_600), usedPercent: 0)
    banked.setManualResetAt(h.now.addingTimeInterval(86_400))
    #expect(banked.visibleResetCountdownTargets.map(\.kind) == [.bankedResetExpiry])
    #expect(banked.visiblePaceTimeLabel == "Time ahead")
    let later = h.model(usedPercent: 0)
    later.setManualResetAt(h.now.addingTimeInterval(8 * 86_400))
    #expect(later.visibleResetCountdownTargets.isEmpty)
    #expect(later.visiblePaceTimeLabel == "Time ahead")
}

@Test @MainActor func stopUntilRemainsVisibleWithAnEstimate() {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model(usedPercent: 100)
    model.setManualResetAt(h.now.addingTimeInterval(3_600))
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.manualEstimate])
    #expect(model.visiblePaceTimeLabel == "Stoppage time")
    #expect(model.paceTimeFields != nil)
    #expect(model.stoppageEndsAt != nil)
}

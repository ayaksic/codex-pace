import Foundation
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@MainActor private final class IdleHarness {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let suite = "PlannedIdleTests.\(UUID())"
    let defaults: UserDefaults
    init() { defaults = UserDefaults(suiteName: suite)! }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    func snapshot(used: Double = 91, account: String = "a", resetHours: Double = 19,
                  fetchedSeconds: Double = 0, bankedHours: Double? = nil) -> PaceSnapshot {
        PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: used, durationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(resetHours * 3_600)),
            fetchedAt: now.addingTimeInterval(fetchedSeconds),
            rateLimitResetCredits: bankedHours.map { hours in
                RateLimitResetCredits(availableCount: 1, credits: [
                    RateLimitResetCredit(id: "b", resetType: "codexRateLimits", status: "available",
                        grantedAt: now, expiresAt: now.addingTimeInterval(hours * 3_600))
                ])
            }, accountID: account)
    }
    func model(_ reading: PaceSnapshot? = nil) -> PaceViewModel {
        PaceViewModel(snapshot: reading ?? snapshot(), now: now, pollingEnabled: false,
            defaults: defaults, creditConsumptionAlert: {}, usageResetAlert: {},
            bankedResetWarning: { _, _ in })
    }
}

@Test @MainActor func plannedSleepChangesPaceWithoutChangingAllowanceOrReset() throws {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    #expect(model.currentPaceState == .behind)
    model.setPlannedIdleHours(8)
    #expect(model.currentPaceState == .ahead)
    #expect(model.activeTimeRemainingSeconds == 11 * 3_600)
    #expect(model.timeRemainingPercentageText == "6.5%")
    #expect(model.timeRemainingLabel == "Active time left")
    #expect(model.snapshot?.weeklyWindow.usageRemainingPercent == 9)
    #expect(model.displayedResetAt == h.snapshot().weeklyWindow.resetsAt)
    #expect(model.stoppageEndsAt == nil)
    #expect(model.menuBarText == "9% / 6.5%")
    let timeline = WeeklyTimelineProgress(window: try #require(model.effectiveWeeklyWindow), at: h.now)
    #expect(abs(timeline.elapsedFraction - (1 - 11.0 / 168)) < 0.000001)
    model.clearPlannedIdleTime()
    #expect(model.currentPaceState == .behind)
    #expect(model.timeRemainingLabel == "Week left")
}

@Test @MainActor func idleMovesRunoutByPlannedBreakAndReducesExtraPause() throws {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    let originalRunout = try #require(model.projectedRunoutAt)
    let originalStoppage = try #require(model.stoppageEndsAt)
    model.setPlannedIdleHours(2.5)
    #expect(model.projectedRunoutAt == originalRunout.addingTimeInterval(2.5 * 3_600))
    #expect(model.stoppageEndsAt == originalStoppage.addingTimeInterval(-2.5 * 3_600))
}

@Test @MainActor func idlePersistsButClearsForNewWindowAccountOrReset() {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    model.setPlannedIdleHours(8)
    #expect(h.model().plannedIdleSeconds == 8 * 3_600)
    model.applyFreshSnapshot(h.snapshot(used: 92, fetchedSeconds: 60), now: h.now.addingTimeInterval(60))
    #expect(model.plannedIdleSeconds == 8 * 3_600)
    model.applyFreshSnapshot(h.snapshot(used: 0, fetchedSeconds: 120), now: h.now.addingTimeInterval(120))
    #expect(model.plannedIdleSeconds == 0)
    #expect(model.usageResetCount == 1)
    #expect(h.model().plannedIdleSeconds == 0)
    model.setPlannedIdleHours(8)
    model.applyFreshSnapshot(h.snapshot(account: "b", fetchedSeconds: 180), now: h.now)
    #expect(model.plannedIdleSeconds == 0)
    model.setPlannedIdleHours(8)
    #expect(h.model(h.snapshot(account: "b", resetHours: 168)).plannedIdleSeconds == 0)
}

@Test @MainActor func resetNotifiesOpenIdleEditorEvenWithoutASavedEstimate() {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    model.applyFreshSnapshot(h.snapshot(used: 0, fetchedSeconds: 60), now: h.now)
    #expect(model.usageResetCount == 1)
    model.applyFreshSnapshot(h.snapshot(used: 0, fetchedSeconds: 120), now: h.now)
    #expect(model.usageResetCount == 1)
}

@Test @MainActor func resetDetectedAfterRelaunchRemovesPersistedIdleEstimate() {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    model.setPlannedIdleHours(8)
    model.applyFreshSnapshot(h.snapshot(fetchedSeconds: 60), now: h.now)
    let relaunched = PaceViewModel(now: h.now, pollingEnabled: false, defaults: h.defaults,
        creditConsumptionAlert: {}, usageResetAlert: {}, bankedResetWarning: { _, _ in })
    relaunched.applyFreshSnapshot(h.snapshot(used: 0, fetchedSeconds: 120), now: h.now)
    #expect(relaunched.usageResetCount == 1)
    #expect(relaunched.plannedIdleSeconds == 0)
    #expect(h.model().plannedIdleSeconds == 0)
}

@Test @MainActor func idleValidatesInputAndClampsAsDeadlineApproaches() {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    for invalid in [-1, Double.nan, Double.infinity, 20] {
        model.setPlannedIdleHours(invalid)
        #expect(model.plannedIdleSeconds == 0)
    }
    model.setPlannedIdleHours(19)
    #expect(model.activeTimeRemainingSeconds == 0)
    #expect(model.paceMetricLabel == "No active time")
    #expect(model.paceMetricValue == nil)
    #expect(model.paceTimeLabel == nil)
    model.applyFreshSnapshot(h.snapshot(fetchedSeconds: 60), now: h.now.addingTimeInterval(18 * 3_600))
    #expect(model.plannedIdleSeconds == 3_600)
    #expect(model.activeTimeRemainingSeconds == 0)
    model.applyFreshSnapshot(h.snapshot(fetchedSeconds: 120), now: h.now.addingTimeInterval(19 * 3_600))
    #expect(model.plannedIdleSeconds == 0)
}

@Test @MainActor func idleUsesEarlierTargetsAndClearsWhenTheyChange() {
    let h = IdleHarness(); defer { h.cleanUp() }
    let model = h.model()
    model.setManualResetAt(h.now.addingTimeInterval(12 * 3_600))
    model.setPlannedIdleHours(8)
    #expect(model.activeTimeRemainingSeconds == 4 * 3_600)
    model.clearManualReset()
    #expect(model.plannedIdleSeconds == 0)
    model.applyFreshSnapshot(h.snapshot(bankedHours: 10), now: h.now)
    model.setPlannedIdleHours(8)
    #expect(model.activeTimeRemainingSeconds == 2 * 3_600)
    #expect(model.resetCountdownTarget?.kind == .bankedResetExpiry)
    model.applyFreshSnapshot(h.snapshot(fetchedSeconds: 60), now: h.now)
    #expect(model.plannedIdleSeconds == 0)
}

private actor IdleSnapshotGate {
    private var reading: PaceSnapshot?
    private var continuation: CheckedContinuation<PaceSnapshot, Never>?

    func fetch() async -> PaceSnapshot {
        if let reading { return reading }
        return await withCheckedContinuation { continuation = $0 }
    }

    func release(_ snapshot: PaceSnapshot) {
        reading = snapshot
        continuation?.resume(returning: snapshot)
        continuation = nil
    }
}

@Test @MainActor func idleSurvivesTimerTicksWhileRelaunchWaitsForFirstReading() async throws {
    let h = IdleHarness(); defer { h.cleanUp() }
    h.model().setPlannedIdleHours(8)
    let reading = h.snapshot()
    let gate = IdleSnapshotGate()
    let model = PaceViewModel(now: h.now, defaults: h.defaults, snapshotProvider: {
        await gate.fetch()
    }, latestRevisionProvider: { "fixture" }, creditConsumptionAlert: {},
       usageResetAlert: {}, bankedResetWarning: { _, _ in })
    for _ in 0..<100 where model.now == h.now {
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    #expect(model.now != h.now)
    #expect(model.snapshot == nil)
    await gate.release(reading)
    for _ in 0..<100 where model.snapshot == nil {
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    #expect(model.snapshot != nil)
    #expect(model.plannedIdleSeconds == 8 * 3_600)
}

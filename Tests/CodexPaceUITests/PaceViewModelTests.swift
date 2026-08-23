import Foundation
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@MainActor
@Test func formatsUsageAndWeekRemainingForMenuBar() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 100,
            resetsAt: now.addingTimeInterval(80.1 * 60)
        ),
        fetchedAt: now
    )

    let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false)

    #expect(model.menuBarText == "76% / 80.1%")
}

@MainActor
@Test func manualResetRecalculatesWeekRemainingAndPaceTiming() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let naturalResetAt = now.addingTimeInterval(80 * 60)
    let manualResetAt = now.addingTimeInterval(40 * 60)
    let suiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 50,
            durationMinutes: 100,
            resetsAt: naturalResetAt
        ),
        fetchedAt: now
    )
    let model = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )

    #expect(model.menuBarText == "50% / 80.0%")
    #expect(model.paceText == "Slow down (-30.0%)")
    #expect(model.paceTimeLabel == "Stoppage time")
    #expect(model.paceTimeFields == DurationFields(hours: 0, minutes: 30, seconds: 0))
    #expect(model.stoppageEndsAt == now.addingTimeInterval(30 * 60))

    model.setManualResetAt(manualResetAt)

    #expect(model.effectiveWeeklyWindow?.resetsAt == manualResetAt)
    #expect(model.menuBarText == "50% / 40.0%")
    #expect(model.paceText == "Speed up (+10.0%)")
    #expect(model.paceTimeLabel == "Time ahead")
    #expect(model.paceTimeFields == DurationFields(hours: 0, minutes: 10, seconds: 0))
    #expect(model.stoppageEndsAt == nil)

    model.clearManualReset()

    #expect(model.effectiveWeeklyWindow?.resetsAt == naturalResetAt)
    #expect(model.menuBarText == "50% / 80.0%")
    #expect(model.paceTimeLabel == "Stoppage time")
}

@MainActor
@Test func formatsPaceAsUsageGuidance() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    func paceText(usedPercent: Double) -> String {
        let snapshot = PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: usedPercent,
                durationMinutes: 100,
                resetsAt: now.addingTimeInterval(50 * 60)
            ),
            fetchedAt: now
        )
        return PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false).paceText
    }

    #expect(paceText(usedPercent: 51.6) == "Slow down (-1.6%)")
    #expect(paceText(usedPercent: 50) == "On pace")
    #expect(paceText(usedPercent: 48.4) == "Speed up (+1.6%)")
}

@MainActor
@Test func formatsZeroUsageCatchUpOnlyWhileSlowingDown() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let durationMinutes = 10_080

    func catchUpText(usedPercent: Double, at date: Date = now) -> String? {
        let snapshot = PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: usedPercent,
                durationMinutes: durationMinutes,
                resetsAt: now.addingTimeInterval(0.801 * Double(durationMinutes) * 60)
            ),
            fetchedAt: now
        )
        return PaceViewModel(snapshot: snapshot, now: date, pollingEnabled: false)
            .zeroUsageCatchUpText
    }

    #expect(catchUpText(usedPercent: 24) == "6h 53m")
    #expect(catchUpText(usedPercent: 24, at: now.addingTimeInterval(60)) == "6h 52m")
    #expect(catchUpText(usedPercent: 19.8) == nil)
    #expect(catchUpText(usedPercent: 18) == nil)
}

@MainActor
@Test func formatsTimeMarginOnEitherSideOfPace() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    func model(usedPercent: Double) -> PaceViewModel {
        let snapshot = PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: usedPercent,
                durationMinutes: 10_080,
                resetsAt: now.addingTimeInterval(0.8 * 10_080 * 60)
            ),
            fetchedAt: now
        )
        return PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false)
    }

    #expect(model(usedPercent: 24).paceTimeLabel == "Stoppage time")
    #expect(
        model(usedPercent: 24).paceTimeFields
            == DurationFields(hours: 6, minutes: 43, seconds: 12)
    )
    #expect(
        model(usedPercent: 24).stoppageEndsAt
            == now.addingTimeInterval(6 * 3_600 + 43 * 60 + 12)
    )
    #expect(model(usedPercent: 20).paceTimeLabel == nil)
    #expect(model(usedPercent: 20).paceTimeFields == nil)
    #expect(model(usedPercent: 20).stoppageEndsAt == nil)
    #expect(model(usedPercent: 16).paceTimeLabel == "Time ahead")
    #expect(
        model(usedPercent: 16).paceTimeFields
            == DurationFields(hours: 6, minutes: 43, seconds: 12)
    )
    #expect(model(usedPercent: 16).stoppageEndsAt == nil)
}

@MainActor
@Test func calculatesRemainingTimeFieldsToTheSecond() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let model = PaceViewModel(now: now, pollingEnabled: false)

    #expect(
        model.remainingTimeFields(until: now.addingTimeInterval(66 * 3_600 + 39 * 60 + 14))
            == DurationFields(hours: 66, minutes: 39, seconds: 14)
    )
    #expect(
        model.remainingTimeFields(until: now.addingTimeInterval(39 * 60 + 14))
            == DurationFields(hours: 0, minutes: 39, seconds: 14)
    )
    #expect(
        model.remainingTimeFields(until: now.addingTimeInterval(-1))
            == DurationFields(hours: 0, minutes: 0, seconds: 0)
    )
}

@MainActor
@Test func calculatesNextRefreshTimestampAndCountdown() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(66 * 3_600)
        ),
        fetchedAt: now
    )
    let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false)

    #expect(model.nextRefreshAt == now.addingTimeInterval(2 * 60))
    #expect(
        model.nextRefreshCountdownFields
            == DurationFields(hours: 0, minutes: 2, seconds: 0)
    )
}

@MainActor
@Test func persistsManualResetEstimateAndFallsBackAfterItExpires() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let reportedResetAt = now.addingTimeInterval(4 * 24 * 3_600)
    let estimatedResetAt = now.addingTimeInterval(2 * 3_600)
    let suiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 10_080,
            resetsAt: reportedResetAt
        ),
        fetchedAt: now
    )

    let model = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )
    #expect(model.displayedResetAt == reportedResetAt)
    #expect(!model.isManualResetActive)

    model.setManualResetAt(estimatedResetAt)
    #expect(model.displayedResetAt == estimatedResetAt)
    #expect(model.isManualResetActive)

    let restoredModel = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )
    #expect(restoredModel.displayedResetAt == estimatedResetAt)
    #expect(restoredModel.isManualResetActive)

    let expiredModel = PaceViewModel(
        snapshot: snapshot,
        now: estimatedResetAt,
        pollingEnabled: false,
        defaults: defaults
    )
    #expect(expiredModel.displayedResetAt == reportedResetAt)
    #expect(!expiredModel.isManualResetActive)
    #expect(defaults.object(forKey: "manualResetAt") == nil)
}

@MainActor
@Test func clearingManualResetRestoresReportedTimestamp() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let reportedResetAt = now.addingTimeInterval(4 * 24 * 3_600)
    let suiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 10_080,
            resetsAt: reportedResetAt
        ),
        fetchedAt: now
    )
    let model = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )

    model.setManualResetAt(now.addingTimeInterval(2 * 3_600))
    model.clearManualReset()

    #expect(model.displayedResetAt == reportedResetAt)
    #expect(!model.isManualResetActive)
    #expect(defaults.object(forKey: "manualResetAt") == nil)
}

@MainActor
@Test func fullUsageRefreshClearsManualResetAndUsesNewReportedTimestamp() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let originalResetAt = now.addingTimeInterval(4 * 24 * 3_600)
    let estimatedResetAt = now.addingTimeInterval(2 * 3_600)
    let newReportedResetAt = now.addingTimeInterval(7 * 24 * 3_600)
    let suiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = PaceViewModel(
        snapshot: PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: 76,
                durationMinutes: 10_080,
                resetsAt: originalResetAt
            ),
            fetchedAt: now
        ),
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )
    model.setManualResetAt(estimatedResetAt)

    let refreshAt = now.addingTimeInterval(60)
    model.applyFreshSnapshot(
        PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: 0,
                durationMinutes: 10_080,
                resetsAt: newReportedResetAt
            ),
            fetchedAt: refreshAt
        ),
        now: refreshAt
    )

    #expect(model.manualResetAt == nil)
    #expect(!model.isManualResetActive)
    #expect(model.displayedResetAt == newReportedResetAt)
    #expect(defaults.object(forKey: "manualResetAt") == nil)
}

@MainActor
@Test func fullUsageResetDetectionSurvivesRelaunch() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let estimatedResetAt = now.addingTimeInterval(2 * 3_600)
    let newReportedResetAt = now.addingTimeInterval(7 * 24 * 3_600)
    let suiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let beforeResetModel = PaceViewModel(
        snapshot: PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: 76,
                durationMinutes: 10_080,
                resetsAt: now.addingTimeInterval(4 * 24 * 3_600)
            ),
            fetchedAt: now
        ),
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )
    beforeResetModel.setManualResetAt(estimatedResetAt)

    let relaunchedModel = PaceViewModel(
        now: now.addingTimeInterval(60),
        pollingEnabled: false,
        defaults: defaults
    )
    relaunchedModel.applyFreshSnapshot(
        PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: 0,
                durationMinutes: 10_080,
                resetsAt: newReportedResetAt
            ),
            fetchedAt: now.addingTimeInterval(60)
        ),
        now: now.addingTimeInterval(60)
    )

    #expect(relaunchedModel.manualResetAt == nil)
    #expect(relaunchedModel.displayedResetAt == newReportedResetAt)
}

@MainActor
@Test func fullUsageRefreshDoesNotClearEstimateSetAtFullUsage() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let estimatedResetAt = now.addingTimeInterval(2 * 3_600)
    let suiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let fullUsageSnapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 0,
            durationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(7 * 24 * 3_600)
        ),
        fetchedAt: now
    )
    let model = PaceViewModel(
        snapshot: fullUsageSnapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )
    model.setManualResetAt(estimatedResetAt)

    model.applyFreshSnapshot(fullUsageSnapshot, now: now.addingTimeInterval(60))

    #expect(model.manualResetAt == estimatedResetAt)
    #expect(model.displayedResetAt == estimatedResetAt)
}

@MainActor
@Test func countsDownToEarliestBankedResetExpiryBeforeNaturalReset() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let naturalResetAt = now.addingTimeInterval(4 * 24 * 3_600)
    let earliestExpiry = now.addingTimeInterval(18 * 3_600)
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 10_080,
            resetsAt: naturalResetAt
        ),
        fetchedAt: now,
        rateLimitResetCredits: RateLimitResetCredits(
            availableCount: 3,
            credits: [
                RateLimitResetCredit(
                    id: "later",
                    resetType: "codexRateLimits",
                    status: "available",
                    grantedAt: now.addingTimeInterval(-3_600),
                    expiresAt: now.addingTimeInterval(2 * 24 * 3_600)
                ),
                RateLimitResetCredit(
                    id: "earlier",
                    resetType: "codexRateLimits",
                    status: "available",
                    grantedAt: now.addingTimeInterval(-3_600),
                    expiresAt: earliestExpiry
                ),
            ]
        )
    )
    let defaultsSuiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: defaultsSuiteName)!
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let model = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )

    #expect(
        model.resetCountdownTarget
            == ResetCountdownTarget(date: earliestExpiry, kind: .bankedResetExpiry)
    )
    #expect(model.availableBankedResetCount == 3)
    #expect(model.availableBankedResetCredits.map(\.id) == ["earlier", "later"])
    #expect(model.bankedResetCountWithoutDetails == 1)

    let manualEstimate = now.addingTimeInterval(6 * 3_600)
    model.setManualResetAt(manualEstimate)
    #expect(
        model.resetCountdownTarget
            == ResetCountdownTarget(date: manualEstimate, kind: .manualEstimate)
    )

    let afterExpiryModel = PaceViewModel(
        snapshot: snapshot,
        now: earliestExpiry,
        pollingEnabled: false,
        defaults: defaults
    )
    #expect(
        afterExpiryModel.resetCountdownTarget
            == ResetCountdownTarget(
                date: now.addingTimeInterval(2 * 24 * 3_600),
                kind: .bankedResetExpiry
            )
    )
}

@MainActor
@Test func ignoresBankedExpiryAfterNaturalResetAndPreservesCountOnlyUncertainty() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let naturalResetAt = now.addingTimeInterval(24 * 3_600)
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 10_080,
            resetsAt: naturalResetAt
        ),
        fetchedAt: now,
        rateLimitResetCredits: RateLimitResetCredits(
            availableCount: 2,
            credits: [
                RateLimitResetCredit(
                    id: "too-late",
                    resetType: "codexRateLimits",
                    status: "available",
                    grantedAt: now.addingTimeInterval(-3_600),
                    expiresAt: now.addingTimeInterval(2 * 24 * 3_600)
                ),
            ]
        )
    )
    let defaultsSuiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: defaultsSuiteName)!
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let model = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )

    #expect(
        model.resetCountdownTarget
            == ResetCountdownTarget(date: naturalResetAt, kind: .natural)
    )
    #expect(model.availableBankedResetCount == 2)
    #expect(model.availableBankedResetCredits.count == 1)
    #expect(model.bankedResetCountWithoutDetails == 1)
}

@MainActor
@Test func preservesBankedResetCountWhenCreditDetailsAreUnavailable() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(
            usedPercent: 24,
            durationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3_600)
        ),
        fetchedAt: now,
        rateLimitResetCredits: RateLimitResetCredits(
            availableCount: 2,
            credits: nil
        )
    )
    let defaultsSuiteName = "PaceViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: defaultsSuiteName)!
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let model = PaceViewModel(
        snapshot: snapshot,
        now: now,
        pollingEnabled: false,
        defaults: defaults
    )

    #expect(model.availableBankedResetCount == 2)
    #expect(model.availableBankedResetCredits.isEmpty)
    #expect(model.bankedResetCountWithoutDetails == 2)
    #expect(model.resetCountdownTarget?.kind == .natural)
}

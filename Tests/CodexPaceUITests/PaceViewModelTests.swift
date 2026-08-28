import Foundation
import Testing
import CodexPaceCore
@testable import CodexPaceUI

private let cleanBuildInfo = AppBuildInfo(
    version: "1.0.0",
    build: "28",
    sourceRevision: "1111111111111111111111111111111111111111",
    sourceState: "clean"
)

@Test func mapsWeeklyUsageAndElapsedTimeOntoTimeline() {
    let reset = Date(timeIntervalSince1970: 2_000_000_000)
    let window = UsageWindow(
        usedPercent: 35,
        durationMinutes: 7 * 24 * 60,
        resetsAt: reset
    )
    let twoDaysAfterStart = reset.addingTimeInterval(-5 * 24 * 3_600)

    let progress = WeeklyTimelineProgress(window: window, at: twoDaysAfterStart)

    #expect(abs(progress.usageUsedFraction - 0.35) < 0.000_001)
    #expect(abs(progress.elapsedFraction - 2.0 / 7.0) < 0.000_001)
    #expect(progress.accessibilityValue == "35% usage consumed, 29% of the window elapsed")
}

@Test func clampsWeeklyTimelineProgressAtWindowBoundaries() {
    let reset = Date(timeIntervalSince1970: 2_000_000_000)
    let window = UsageWindow(
        usedPercent: 120,
        durationMinutes: 7 * 24 * 60,
        resetsAt: reset
    )

    let beforeWindow = WeeklyTimelineProgress(
        window: window,
        at: reset.addingTimeInterval(-8 * 24 * 3_600)
    )
    let afterWindow = WeeklyTimelineProgress(
        window: window,
        at: reset.addingTimeInterval(60)
    )

    #expect(beforeWindow.usageUsedFraction == 1)
    #expect(beforeWindow.elapsedFraction == 0)
    #expect(afterWindow.elapsedFraction == 1)
}

@Test func durationDisplayOmitsZeroUnitsWithoutLargerUnitsToTheirLeft() {
    let days = DurationDisplay(
        fields: DurationFields(days: 6, hours: 0, minutes: 47, seconds: 18)
    )
    #expect(days.days == "6d")
    #expect(days.hours == "0h")
    #expect(days.minutes == "47m")
    #expect(days.seconds == "18s")
    #expect(days.accessibilityLabel == "6 days, 0 hours, 47 minutes, 18 seconds")

    let hours = DurationDisplay(
        fields: DurationFields(hours: 13, minutes: 0, seconds: 54)
    )
    #expect(hours.days == nil)
    #expect(hours.hours == "13h")
    #expect(hours.minutes == "0m")
    #expect(hours.seconds == "54s")
    #expect(hours.accessibilityLabel == "13 hours, 0 minutes, 54 seconds")

    let minutes = DurationDisplay(
        fields: DurationFields(hours: 0, minutes: 47, seconds: 18)
    )
    #expect(minutes.days == nil)
    #expect(minutes.hours == nil)
    #expect(minutes.minutes == "47m")
    #expect(minutes.seconds == "18s")
    #expect(minutes.accessibilityLabel == "47 minutes, 18 seconds")

    let seconds = DurationDisplay(
        fields: DurationFields(hours: 0, minutes: 0, seconds: 39)
    )
    #expect(seconds.days == nil)
    #expect(seconds.hours == nil)
    #expect(seconds.minutes == nil)
    #expect(seconds.seconds == "39s")
    #expect(seconds.accessibilityLabel == "39 seconds")

    let zero = DurationDisplay(
        fields: DurationFields(hours: 0, minutes: 0, seconds: 0)
    )
    #expect(zero.days == nil)
    #expect(zero.hours == nil)
    #expect(zero.minutes == nil)
    #expect(zero.seconds == "0s")
    #expect(zero.accessibilityLabel == "0 seconds")
}

@MainActor
@Test func identifiesWhetherInstalledBuildIsLatest() async {
    let latestModel = PaceViewModel(
        pollingEnabled: false,
        appBuildInfo: cleanBuildInfo,
        latestRevisionProvider: { cleanBuildInfo.sourceRevision }
    )
    await latestModel.checkForUpdates()
    #expect(latestModel.appUpdateStatus == .latest)
    #expect(latestModel.appUpdateStatusText == "Latest")

    let newerRevision = "2222222222222222222222222222222222222222"
    let olderModel = PaceViewModel(
        pollingEnabled: false,
        appBuildInfo: cleanBuildInfo,
        latestRevisionProvider: { newerRevision }
    )
    await olderModel.checkForUpdates()
    #expect(olderModel.appUpdateStatus == .notLatest(latestRevision: newerRevision))
    #expect(olderModel.appUpdateStatusText == "Not latest")
}

@MainActor
@Test func labelsModifiedBuildWithoutClaimingItIsLatest() async {
    let model = PaceViewModel(
        pollingEnabled: false,
        appBuildInfo: AppBuildInfo(
            version: "1.0.0",
            build: "28",
            sourceRevision: cleanBuildInfo.sourceRevision,
            sourceState: "modified"
        ),
        latestRevisionProvider: { cleanBuildInfo.sourceRevision }
    )

    await model.checkForUpdates()

    #expect(model.appUpdateStatus == .developmentBuild)
    #expect(model.appUpdateStatusText == "Development build")
}

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

    #expect(model.menuBarText == "80.1% / 76%")
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

    #expect(model.menuBarText == "80.0% / 50%")
    #expect(model.paceText == "Slow down (-30.0%)")
    #expect(model.paceMetricLabel == "Slow down")
    #expect(model.paceMetricValue == "-30.0%")
    #expect(model.paceTimeLabel == "Stoppage time")
    #expect(model.paceTimeFields == DurationFields(hours: 0, minutes: 30, seconds: 0))
    #expect(model.stoppageEndsAt == now.addingTimeInterval(30 * 60))
    #expect(model.projectedRunoutAt == now.addingTimeInterval(24 * 60))
    #expect(
        model.projectedRunoutCountdownFields
            == DurationFields(hours: 0, minutes: 24, seconds: 0)
    )

    let oneMinuteLater = PaceViewModel(
        snapshot: snapshot,
        now: now.addingTimeInterval(60),
        pollingEnabled: false,
        defaults: defaults
    )
    #expect(oneMinuteLater.projectedRunoutAt == now.addingTimeInterval(24 * 60))
    #expect(
        oneMinuteLater.projectedRunoutCountdownFields
            == DurationFields(hours: 0, minutes: 23, seconds: 0)
    )

    model.setManualResetAt(manualResetAt)

    #expect(model.effectiveWeeklyWindow?.resetsAt == manualResetAt)
    #expect(model.menuBarText == "40.0% / 50%")
    #expect(model.paceText == "Speed up (+10.0%)")
    #expect(model.paceMetricLabel == "Speed up")
    #expect(model.paceMetricValue == "+10.0%")
    #expect(model.paceTimeLabel == "Time ahead")
    #expect(model.paceTimeFields == DurationFields(hours: 0, minutes: 10, seconds: 0))
    #expect(model.stoppageEndsAt == nil)
    #expect(model.projectedRunoutAt == nil)
    #expect(model.projectedRunoutCountdownFields == nil)

    model.clearManualReset()

    #expect(model.effectiveWeeklyWindow?.resetsAt == naturalResetAt)
    #expect(model.menuBarText == "80.0% / 50%")
    #expect(model.paceTimeLabel == "Stoppage time")
    #expect(model.projectedRunoutAt == now.addingTimeInterval(24 * 60))
    #expect(
        model.projectedRunoutCountdownFields
            == DurationFields(hours: 0, minutes: 24, seconds: 0)
    )
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
    #expect(paceText(usedPercent: 50.04) == "On pace")
    #expect(paceText(usedPercent: 50) == "On pace")
    #expect(paceText(usedPercent: 49.96) == "On pace")
    #expect(paceText(usedPercent: 48.4) == "Speed up (+1.6%)")
    #expect(paceText(usedPercent: 100) == "Stopped")
}

@MainActor
@Test func formatsPaceMetricForEveryState() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    func model(usedPercent: Double) -> PaceViewModel {
        PaceViewModel(
            snapshot: PaceSnapshot(
                weeklyWindow: UsageWindow(
                    usedPercent: usedPercent,
                    durationMinutes: 100,
                    resetsAt: now.addingTimeInterval(50 * 60)
                ),
                fetchedAt: now
            ),
            now: now,
            pollingEnabled: false
        )
    }

    #expect(model(usedPercent: 51.6).paceMetricLabel == "Slow down")
    #expect(model(usedPercent: 51.6).paceMetricValue == "-1.6%")
    #expect(model(usedPercent: 50.04).paceMetricLabel == "On pace")
    #expect(model(usedPercent: 50.04).paceMetricValue == "0.0%")
    #expect(model(usedPercent: 50).paceMetricLabel == "On pace")
    #expect(model(usedPercent: 50).paceMetricValue == "0.0%")
    #expect(model(usedPercent: 49.96).paceMetricLabel == "On pace")
    #expect(model(usedPercent: 49.96).paceMetricValue == "0.0%")
    #expect(model(usedPercent: 48.4).paceMetricLabel == "Speed up")
    #expect(model(usedPercent: 48.4).paceMetricValue == "+1.6%")
    #expect(model(usedPercent: 100).paceMetricLabel == "Stopped")
    #expect(model(usedPercent: 100).paceMetricValue == nil)
}

@MainActor
@Test func keepsExactTimingDetailWhenRoundedHeadlineIsOnPace() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    func model(usedPercent: Double) -> PaceViewModel {
        PaceViewModel(
            snapshot: PaceSnapshot(
                weeklyWindow: UsageWindow(
                    usedPercent: usedPercent,
                    durationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(0.5 * 10_080 * 60)
                ),
                fetchedAt: now
            ),
            now: now,
            pollingEnabled: false
        )
    }

    let slightlyBehind = model(usedPercent: 50.04)
    #expect(slightlyBehind.paceMetricState == .onPace)
    #expect(slightlyBehind.currentPaceState == .behind)
    #expect(slightlyBehind.paceTimeLabel == "Stoppage time")
    #expect(slightlyBehind.paceTimeFields == DurationFields(hours: 0, minutes: 4, seconds: 1))
    #expect(slightlyBehind.projectedRunoutAt == nil)
    #expect(slightlyBehind.projectedRunoutCountdownFields == nil)

    let slightlyAhead = model(usedPercent: 49.96)
    #expect(slightlyAhead.paceMetricState == .onPace)
    #expect(slightlyAhead.currentPaceState == .ahead)
    #expect(slightlyAhead.paceTimeLabel == "Time ahead")
    #expect(slightlyAhead.paceTimeFields == DurationFields(hours: 0, minutes: 4, seconds: 1))
    #expect(slightlyAhead.projectedRunoutAt == nil)
    #expect(slightlyAhead.projectedRunoutCountdownFields == nil)
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
        model.remainingTimeFields(until: now.addingTimeInterval(166 * 3_600))
            == DurationFields(days: 6, hours: 22, minutes: 0, seconds: 0)
    )
    #expect(
        model.remainingTimeFields(until: now.addingTimeInterval(66 * 3_600 + 39 * 60 + 14))
            == DurationFields(days: 2, hours: 18, minutes: 39, seconds: 14)
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

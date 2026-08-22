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
    #expect(model(usedPercent: 24).paceTimeText == "6h 43m")
    #expect(model(usedPercent: 20).paceTimeLabel == nil)
    #expect(model(usedPercent: 20).paceTimeText == nil)
    #expect(model(usedPercent: 16).paceTimeLabel == "Time ahead")
    #expect(model(usedPercent: 16).paceTimeText == "6h 43m")
}

@MainActor
@Test func formatsElapsedSecondsWithoutLeadingZero() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let model = PaceViewModel(now: now, pollingEnabled: false)

    #expect(model.elapsedText(since: now.addingTimeInterval(-5)) == "5s ago")
    #expect(model.elapsedText(since: now.addingTimeInterval(-65)) == "1m 5s ago")
}

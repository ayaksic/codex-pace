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

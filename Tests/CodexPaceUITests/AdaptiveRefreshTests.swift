import CodexPaceCore
import Foundation
import Testing
@testable import CodexPaceUI

@MainActor
@Test(arguments: [0.0, 97.0, 98.0, 98.49, 98.5, 98.51, 99.0, 99.6, 100.0])
func adaptiveRefreshMatchesDisplayedRemainingUsage(usedPercent: Double) {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snapshot = PaceSnapshot(
        weeklyWindow: UsageWindow(usedPercent: usedPercent, durationMinutes: 10_080,
                                  resetsAt: now.addingTimeInterval(3_600)),
        fetchedAt: now
    )
    let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false)
    let fast = model.menuBarText.hasPrefix("1% / ") || model.menuBarText.hasPrefix("0% / ")
    let expected: TimeInterval = fast ? 15 : 60
    #expect(model.autoRefreshInterval == expected)
    #expect(model.nextRefreshAt == now.addingTimeInterval(expected))
    #expect(!model.isAutoRefreshDue(at: now.addingTimeInterval(expected - 1)))
    #expect(model.isAutoRefreshDue(at: now.addingTimeInterval(expected)))
    #expect(model.nextRefreshCountdownFields == DurationFields(
        hours: 0, minutes: fast ? 0 : 1, seconds: fast ? 15 : 0
    ))
}

@MainActor
@Test func refreshIntervalReturnsToNormalAfterUsageResets() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let suiteName = "AdaptiveRefreshTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = PaceViewModel(now: now, pollingEnabled: false, defaults: defaults,
                              usageResetAlert: {})
    #expect(model.autoRefreshInterval == 60)
    #expect(model.nextRefreshAt == nil)
    #expect(model.isAutoRefreshDue(at: now))
    for (index, used) in [98.0, 99.0, 100.0, 0.0, 98.0].enumerated() {
        let readingAt = now.addingTimeInterval(Double(index) * 60)
        model.applyFreshSnapshot(PaceSnapshot(
            weeklyWindow: UsageWindow(usedPercent: used, durationMinutes: 10_080,
                                      resetsAt: now.addingTimeInterval(7 * 86_400)),
            fetchedAt: readingAt
        ), now: readingAt)
        #expect(model.autoRefreshInterval == (used >= 99 ? 15 : 60))
        #expect(model.nextRefreshAt == readingAt.addingTimeInterval(used >= 99 ? 15 : 60))
    }
}

@MainActor
@Test func failedRefreshKeepsFastRetryBasedOnLastAttempt() async {
    let now = Date()
    let model = PaceViewModel(
        snapshot: PaceSnapshot(
            weeklyWindow: UsageWindow(usedPercent: 99, durationMinutes: 10_080,
                                      resetsAt: now.addingTimeInterval(3_600)),
            fetchedAt: now
        ), now: now, pollingEnabled: false,
        snapshotProvider: { throw CodexRateLimitClientError.responseTimedOut }
    )
    await model.refresh()
    #expect(model.errorMessage != nil)
    #expect(model.autoRefreshInterval == 15)
    let next = model.nextRefreshAt!
    #expect(next >= now.addingTimeInterval(15))
    #expect(!model.isAutoRefreshDue(at: next.addingTimeInterval(-1)))
    #expect(model.isAutoRefreshDue(at: next))
    #expect(!model.isRefreshing)
}

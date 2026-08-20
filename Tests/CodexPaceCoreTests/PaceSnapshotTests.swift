import Foundation
import Testing
@testable import CodexPaceCore

@Test func calculatesRemainingWindowAndPace() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let weekSeconds = 7.0 * 24 * 60 * 60
    let window = UsageWindow(
        usedPercent: 18,
        durationMinutes: 10_080,
        resetsAt: now.addingTimeInterval(weekSeconds * 0.825)
    )
    let snapshot = PaceSnapshot(weeklyWindow: window, fetchedAt: now)

    #expect(window.usageRemainingPercent == 82)
    #expect(abs(window.timeRemainingPercent(at: now) - 82.5) < 0.001)
    #expect(abs(window.timeRemainingHours(at: now) - 138.6) < 0.001)
    #expect(abs(snapshot.paceDeltaPercentagePoints(at: now) + 0.5) < 0.001)
    #expect(snapshot.paceState(at: now) == .onPace)
}

@Test func clampsTimeAtWindowBoundaries() {
    let reset = Date(timeIntervalSince1970: 2_000_000_000)
    let window = UsageWindow(usedPercent: 0, durationMinutes: 10_080, resetsAt: reset)

    #expect(window.timeRemainingPercent(at: reset.addingTimeInterval(-700_000)) == 100)
    #expect(window.timeRemainingPercent(at: reset.addingTimeInterval(1)) == 0)
    #expect(window.timeRemainingHours(at: reset.addingTimeInterval(1)) == 0)
}

@Test func selectsWeeklyWindowWhenFiveHourWindowIsPrimary() throws {
    let fetchedAt = Date(timeIntervalSince1970: 1_787_000_000)
    let json = #"""
    {
      "id": 2,
      "result": {
        "rateLimits": {
          "primary": {"usedPercent": 40, "windowDurationMins": 300, "resetsAt": 1787001000},
          "secondary": {"usedPercent": 18, "windowDurationMins": 10080, "resetsAt": 1787604800},
          "credits": {"balance": "0"},
          "planType": "pro"
        },
        "rateLimitsByLimitId": null
      }
    }
    """#.data(using: .utf8)!

    let snapshot = try CodexRateLimitClient.decodeRateLimitResponse(json, fetchedAt: fetchedAt)

    #expect(snapshot.weeklyWindow.usedPercent == 18)
    #expect(snapshot.weeklyWindow.durationMinutes == 10_080)
    #expect(snapshot.shortWindow?.durationMinutes == 300)
    #expect(snapshot.planType == "pro")
    #expect(snapshot.creditBalance == "0")
}

@Test func prefersCodexBucketInMultiBucketResponse() throws {
    let json = #"""
    {
      "id": 2,
      "result": {
        "rateLimits": {
          "primary": {"usedPercent": 99, "windowDurationMins": 10080, "resetsAt": 1787604800},
          "secondary": null,
          "credits": null,
          "planType": "pro"
        },
        "rateLimitsByLimitId": {
          "codex": {
            "primary": {"usedPercent": 18, "windowDurationMins": 10080, "resetsAt": 1787604800},
            "secondary": null,
            "credits": {"balance": "0"},
            "planType": "pro"
          }
        }
      }
    }
    """#.data(using: .utf8)!

    let snapshot = try CodexRateLimitClient.decodeRateLimitResponse(json)
    #expect(snapshot.weeklyWindow.usedPercent == 18)
}

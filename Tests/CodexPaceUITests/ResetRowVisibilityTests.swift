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
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.bankedResetExpiry])
    model.setManualResetAt(h.now.addingTimeInterval(2 * 86_400))
    #expect(model.resetCountdownTarget?.kind == .bankedResetExpiry)
    #expect(model.visibleResetCountdownTargets == [ResetCountdownTarget(date: expiry, kind: .bankedResetExpiry)])
    #expect(model.effectiveWeeklyWindow?.resetsAt == expiry)
    model.clearManualReset()
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.bankedResetExpiry])
}

@Test @MainActor func bankedExpiryHidesReportedResetUntilNoEarlierExpiryRemains() throws {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let expiry = h.now.addingTimeInterval(86_400)
    let model = h.model(bankedExpiry: expiry)
    #expect(model.visibleResetCountdownTargets == [ResetCountdownTarget(date: expiry, kind: .bankedResetExpiry)])
    #expect(model.visibleBankedResetCredits.isEmpty)
    model.applyFreshSnapshot(try #require(model.snapshot), now: expiry)
    #expect(model.visibleResetCountdownTargets.map(\.kind) == [.natural])
}

@Test(arguments: [0, 1, 2]) @MainActor
func usageCreditsSortBeforeBetweenOrAfterBankedExpirations(position: Int) throws {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model(bankedExpiry: h.now.addingTimeInterval(3_600))
    let expiration = try #require(CreditExpirationNote("2033-06-01"))
    model.setCreditExpirationNote(expiration)
    let date = try #require(model.creditExpirationAt)
    let snapshot = try #require(model.snapshot)
    let active = try #require(model.availableBankedResetCredits.first)
    let credits = (0..<2).map { index in
        RateLimitResetCredit(id: "sorted-\(index)", resetType: "codexRateLimits", status: "available",
            grantedAt: h.now, expiresAt: date.addingTimeInterval(Double(index - position) * 86_400 + 3_600))
    }
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: snapshot.weeklyWindow, fetchedAt: h.now,
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 3, credits: [credits[1], active, credits[0]])),
        now: h.now)
    var expected = credits.map(ExpirationRow.bankedReset)
    expected.insert(.usageCredits(date), at: position)
    #expect(model.visibleExpirationRows == expected)
    #expect(model.availableBankedResetCount == 3)
    model.removeCreditExpirationNote()
    #expect(model.visibleExpirationRows == credits.map(ExpirationRow.bankedReset) + [.usageCredits(nil)])
}

@Test @MainActor func equalAndUnknownExpirationsKeepStableRowsAndMissingDetailCounts() throws {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let model = h.model()
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2033-06-01")))
    let date = try #require(model.creditExpirationAt)
    let sameDate = RateLimitResetCredit(id: "same-date", resetType: "codexRateLimits", status: "available",
        grantedAt: h.now, expiresAt: date)
    let undated = RateLimitResetCredit(id: "undated", resetType: "codexRateLimits", status: "available",
        grantedAt: h.now, expiresAt: nil)
    let snapshot = try #require(model.snapshot)
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: snapshot.weeklyWindow, fetchedAt: h.now,
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 3, credits: [undated, sameDate])), now: h.now)
    #expect(model.visibleExpirationRows == [.usageCredits(date), .bankedReset(sameDate), .bankedReset(undated)])
    #expect(model.bankedResetCountWithoutDetails == 1)
    model.removeCreditExpirationNote()
    #expect(model.visibleExpirationRows == [.bankedReset(sameDate), .usageCredits(nil), .bankedReset(undated)])
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

@Test @MainActor func bankedRowsFollowTheDisplayedExpiryWithoutChangingAvailability() throws {
    let h = ResetRowHarness()
    defer { h.cleanUp() }
    let expiry = h.now.addingTimeInterval(86_400)
    let model = h.model(bankedExpiry: expiry)
    let original = try #require(model.snapshot)
    let first = try #require(model.availableBankedResetCredits.first)
    let later = RateLimitResetCredit(id: "later", resetType: "codexRateLimits", status: "available",
        grantedAt: h.now, expiresAt: expiry.addingTimeInterval(86_400))
    let undated = RateLimitResetCredit(id: "undated", resetType: "codexRateLimits", status: "available",
        grantedAt: h.now, expiresAt: nil)
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: original.weeklyWindow, fetchedAt: h.now,
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 4, credits: [first, later, undated])),
        now: h.now)
    #expect(model.visibleBankedResetCredits.map(\.id) == ["later", "undated"])
    #expect(model.availableBankedResetCount == 4)
    #expect(model.availableBankedResetCredits.count == 3)
    #expect(model.bankedResetCountWithoutDetails == 1)

    // An earlier estimate replaces Reset expires, so the banked row returns.
    model.setManualResetAt(h.now.addingTimeInterval(3_600))
    #expect(model.visibleBankedResetCredits.map(\.id) == [first.id, "later", "undated"])
    model.clearManualReset()
    #expect(model.visibleBankedResetCredits.map(\.id) == ["later", "undated"])

    // As the first reset expires, the next one becomes the pacing target.
    model.applyFreshSnapshot(try #require(model.snapshot), now: expiry)
    #expect(model.resetCountdownTarget?.date == later.expiresAt)
    #expect(model.visibleBankedResetCredits.map(\.id) == ["undated"])
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

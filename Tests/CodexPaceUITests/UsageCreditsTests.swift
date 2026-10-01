import Foundation
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@Test func creditBalanceFormattingPreservesDecimalsAndUnknownValues() {
    #expect(UsageCreditBalance.formatted("62500") == "62,500")
    #expect(UsageCreditBalance.formatted("62500.12500") == "62,500.125")
    #expect(UsageCreditBalance.formatted("0.000000000000000001") == "0.000000000000000001")
    #expect(UsageCreditBalance.formatted("0") == "0")
    #expect(UsageCreditBalance.formatted("0.00") == "0")
    for value in [nil, "", "unavailable", "NaN", "62,500", "1.2.3", "1\n"] as [String?] {
        #expect(UsageCreditBalance.formatted(value) == nil)
    }
}

@Test func expirationIsAValidatedCalendarDate() {
    #expect(CreditExpirationNote("2026-12-31")?.isoDate == "2026-12-31")
    #expect(CreditExpirationNote("2028-02-29") != nil)
    for value in ["2026-02-29", "2026-13-01", "2026-04-31", "2026-1-1", "2026-12-31T00:00:00Z", "0000-01-01"] {
        #expect(CreditExpirationNote(value) == nil)
    }
}

@Test func calendarDaysRespectTimeZonesAndDST() throws {
    let iso = ISO8601DateFormatter()
    let ny = try #require(TimeZone(identifier: "America/New_York"))
    // Both DST transitions contain calendar days that are not 24 hours long.
    for (today, end) in [("2026-03-08T05:00:00Z", "2026-03-09"), ("2026-11-01T04:00:00Z", "2026-11-02")] {
        let note = try #require(CreditExpirationNote(end))
        #expect(note.daysRemaining(at: try #require(iso.date(from: today)), timeZone: ny) == 1)
    }
    let instant = try #require(iso.date(from: "2027-01-01T02:00:00Z"))
    let note = try #require(CreditExpirationNote("2026-12-31"))
    #expect(note.daysRemaining(at: instant, timeZone: ny) == 0)
    #expect(note.daysRemaining(at: instant, timeZone: TimeZone(secondsFromGMT: 0)!) == -1)
    #expect(note.daysRemaining(at: instant, timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))) == -1)
}

@Test @MainActor func noteSaveEditRemoveAndRelaunch() throws {
    let suite = "UsageCreditsTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    func load() -> PaceViewModel { PaceViewModel(pollingEnabled: false, defaults: defaults) }
    let model = load()
    #expect(model.creditExpirationNote == nil) // No universal gift default.
    let first = try #require(CreditExpirationNote("2026-12-31"))
    model.setCreditExpirationNote(first)
    #expect(defaults.string(forKey: PaceViewModel.creditExpirationNoteKey) == "2026-12-31")
    #expect(load().creditExpirationNote == first)
    let edited = try #require(CreditExpirationNote("2027-01-15"))
    model.setCreditExpirationNote(edited)
    #expect(load().creditExpirationNote == edited)
    model.removeCreditExpirationNote()
    #expect(load().creditExpirationNote == nil)
    #expect(defaults.object(forKey: PaceViewModel.creditExpirationNoteKey) == nil)
}

@Test @MainActor func freshMissingZeroFailedAndExpiredNotesRemainIndependent() async throws {
    let suite = "UsageCreditsTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    func snapshot(_ balance: String?) -> PaceSnapshot {
        PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: 20, durationMinutes: 10_080,
                                             resetsAt: now.addingTimeInterval(86_400)),
                     fetchedAt: now, creditBalance: balance)
    }
    let model = PaceViewModel(snapshot: snapshot("62500"), now: now, pollingEnabled: false,
                              defaults: defaults, snapshotProvider: { throw CocoaError(.fileReadUnknown) })
    let window = model.effectiveWeeklyWindow
    let reset = model.resetCountdownTarget
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    #expect(model.creditExpirationDayText == "Expiration date passed")
    #expect(model.usageCreditBalanceText == "62,500")
    #expect(model.effectiveWeeklyWindow == window)
    #expect(model.resetCountdownTarget == reset)
    await model.refresh()
    #expect(model.usageCreditReadingLabel == "Last known balance")
    #expect(model.usageCreditBalanceText == "62,500")
    #expect(model.creditExpirationNote != nil)
    model.applyFreshSnapshot(snapshot(nil), now: now)
    #expect(model.usageCreditBalanceText == "Unavailable")
    #expect(model.usageCreditReadingLabel == "Balance")
    model.applyFreshSnapshot(snapshot("garbage"), now: now)
    #expect(model.usageCreditBalanceText == "Unavailable")
    model.applyFreshSnapshot(snapshot("0"), now: now)
    #expect(model.usageCreditBalanceText == "0")
    #expect(model.creditExpirationNote != nil)
}

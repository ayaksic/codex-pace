import CodexPaceCore
import Foundation

public struct DurationFields: Equatable, Sendable {
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    public init(days: Int = 0, hours: Int, minutes: Int, seconds: Int) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}

public enum ResetCountdownKind: Equatable, Sendable {
    case natural
    case manualEstimate
    case bankedResetExpiry
}

public enum AppUpdateStatus: Equatable, Sendable {
    case notChecked
    case checking
    case latest
    case notLatest(latestRevision: String)
    case developmentBuild
    case failed
}

public struct ResetCountdownTarget: Equatable, Sendable {
    public let date: Date
    public let kind: ResetCountdownKind

    public init(date: Date, kind: ResetCountdownKind) {
        self.date = date
        self.kind = kind
    }
}

@MainActor
public final class PaceViewModel: ObservableObject {
    private struct UsageResetReading: Codable {
        let usedPercent: Double
        let fetchedAt: Date

        init(_ snapshot: PaceSnapshot) {
            usedPercent = snapshot.weeklyWindow.usedPercent
            fetchedAt = snapshot.fetchedAt
        }
    }

    private static let usageResetReadingKey = "usageResetReading"
    private static let lastCreditConsumptionAlertKey = "lastCreditConsumptionAlert"
    private static let updateCheckInterval: TimeInterval = 6 * 60 * 60
    private static let manualResetAtKey = "manualResetAt"
    private static let lastWeeklyUsageRemainingPercentKey = "lastWeeklyUsageRemainingPercent"

    public static let creditExpirationNoteKey = "usageCreditExpirationNote"
    @Published public private(set) var creditExpirationNote: CreditExpirationNote?

    @Published public private(set) var snapshot: PaceSnapshot?
    @Published public private(set) var now: Date
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var manualResetAt: Date?
    @Published public private(set) var appUpdateStatus: AppUpdateStatus = .notChecked

    public let appBuildInfo: AppBuildInfo

    private var timer: Timer?
    private var lastAttempt: Date?
    private var lastWeeklyUsageRemainingPercent: Double?
    private var lastUpdateCheckAttempt: Date?
    private let snapshotProvider: @Sendable () async throws -> PaceSnapshot
    private let defaults: UserDefaults
    private let latestRevisionProvider: @Sendable () async throws -> String
    private let creditConsumptionAlert: @MainActor () -> Void
    private let usageResetAlert: @MainActor () -> Void
    private var lastUsageResetReading: (accountID: String?, reading: UsageResetReading)?
    private var bankedResetReminders: BankedResetReminderHistory
    private let bankedResetWarning: @MainActor ([BankedResetExpiryWarning], Bool) -> Void

    public init(
        snapshot: PaceSnapshot? = nil,
        now: Date = Date(),
        pollingEnabled: Bool = true,
        defaults: UserDefaults = .standard,
        appBuildInfo: AppBuildInfo = AppBuildInfo(),
        snapshotProvider: @escaping @Sendable () async throws -> PaceSnapshot = {
            try await Task.detached(priority: .utility) { try CodexRateLimitClient().fetch() }.value
        },
        latestRevisionProvider: @escaping @Sendable () async throws -> String = {
            try await GitHubLatestRevisionClient.shared.latestRevision()
        },
        creditConsumptionAlert: (@MainActor () -> Void)? = nil,
        usageResetAlert: (@MainActor () -> Void)? = nil,
        bankedResetWarning: (@MainActor ([BankedResetExpiryWarning], Bool) -> Void)? = nil
    ) {
        self.snapshotProvider = snapshotProvider
        self.creditExpirationNote = defaults.string(forKey: Self.creditExpirationNoteKey).flatMap(CreditExpirationNote.init)
        self.snapshot = snapshot
        self.now = now
        self.defaults = defaults
        self.appBuildInfo = appBuildInfo
        self.latestRevisionProvider = latestRevisionProvider
        self.creditConsumptionAlert = creditConsumptionAlert ?? {
            UsageCreditAlertPresenter.shared.show()
        }
        self.usageResetAlert = usageResetAlert ?? {
            UsageResetAlertPresenter.shared.show()
        }
        self.bankedResetReminders = BankedResetReminderHistory(defaults: defaults)
        self.bankedResetWarning = bankedResetWarning ?? { warnings, shouldPresent in
            BankedResetExpiryAlertPresenter.shared.update(warnings, shouldPresent: shouldPresent)
        }
        self.lastUsageResetReading = snapshot.map { ($0.accountID, UsageResetReading($0)) }
        self.lastWeeklyUsageRemainingPercent = defaults.object(
            forKey: Self.lastWeeklyUsageRemainingPercentKey
        ) as? Double

        if let storedDate = defaults.object(forKey: Self.manualResetAtKey) as? Date,
           storedDate > now {
            manualResetAt = storedDate
        } else {
            manualResetAt = nil
            defaults.removeObject(forKey: Self.manualResetAtKey)
        }

        guard pollingEnabled else { return }
        Task { await refresh() }
        Task { await checkForUpdates() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = Date()
                self.clearExpiredManualResetIfNeeded()
                if self.isAutoRefreshDue(at: self.now) {
                    await self.refresh()
                }
                self.checkBankedResetReminders()
                if self.lastUpdateCheckAttempt.map({
                    self.now.timeIntervalSince($0) >= Self.updateCheckInterval
                }) ?? true {
                    await self.checkForUpdates()
                }
            }
        }
    }

    public var usageCreditBalanceText: String {
        UsageCreditBalance.formatted(snapshot?.creditBalance) ?? "Unavailable"
    }

    public var compactUsageCreditBalanceText: String? {
        UsageCreditBalance.compactFormatted(snapshot?.creditBalance)
    }

    public var creditExpirationAt: Date? { creditExpirationNote?.midnight() }

    public var usageCreditReadingLabel: String {
        errorMessage != nil && UsageCreditBalance.formatted(snapshot?.creditBalance) != nil
            ? "Last known balance" : "Balance"
    }

    public var creditExpirationDayText: String? {
        guard let note = creditExpirationNote else { return nil }
        let days = note.daysRemaining(at: now)
        if days < 0 { return "Expiration date passed" }
        if days == 0 { return "0 days" }
        return "\(days) day\(days == 1 ? "" : "s")"
    }

    public func setCreditExpirationNote(_ note: CreditExpirationNote) {
        creditExpirationNote = note
        defaults.set(note.isoDate, forKey: Self.creditExpirationNoteKey)
    }

    public func removeCreditExpirationNote() {
        creditExpirationNote = nil
        defaults.removeObject(forKey: Self.creditExpirationNoteKey)
    }

    public var appUpdateStatusText: String {
        switch appUpdateStatus {
        case .notChecked:
            "Check latest"
        case .checking:
            "Checking…"
        case .latest:
            "Latest"
        case .notLatest:
            "Not latest"
        case .developmentBuild:
            "Development build"
        case .failed:
            "Check failed"
        }
    }

    public func checkForUpdates() async {
        guard appUpdateStatus != .checking else { return }
        guard appBuildInfo.canCheckLatestRevision else {
            appUpdateStatus = .developmentBuild
            return
        }

        lastUpdateCheckAttempt = Date()
        appUpdateStatus = .checking
        do {
            let latestRevision = try await latestRevisionProvider()
            if latestRevision == appBuildInfo.sourceRevision {
                appUpdateStatus = .latest
            } else {
                appUpdateStatus = .notLatest(latestRevision: latestRevision)
            }
        } catch {
            appUpdateStatus = .failed
        }
    }

    public var menuBarText: String {
        guard let weeklyWindow = effectiveWeeklyWindow else { return "— / —" }
        let usage = weeklyWindow.usageRemainingPercent.formatted(
            .number
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        let time = weeklyWindow.timeRemainingPercent(at: now).formatted(
            .number
                .precision(.fractionLength(1))
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        return "\(usage)% / \(time)%"
    }

    public var paceText: String {
        if paceMetricState == .onPace { return paceMetricLabel }
        guard let paceMetricValue else { return paceMetricLabel }
        return "\(paceMetricLabel) (\(paceMetricValue))"
    }

    public var paceMetricLabel: String {
        if effectiveWeeklyWindow?.usageRemainingPercent == 0 { return "Stopped" }
        switch paceMetricState {
        case .ahead:
            return "Speed up"
        case .onPace:
            return "On pace"
        case .behind:
            return "Slow down"
        case nil:
            return "Unavailable"
        }
    }

    public var paceMetricValue: String? {
        guard effectiveWeeklyWindow?.usageRemainingPercent != 0,
              let delta = currentPaceDelta,
              let state = paceMetricState else { return nil }
        if state == .onPace { return "0.0%" }
        return delta.formatted(
            .number.sign(strategy: .always()).precision(.fractionLength(1))
        ) + "%"
    }

    public var zeroUsageCatchUpText: String? {
        guard
            let interval = effectiveWeeklyWindow?.zeroUsageCatchUpTimeInterval(at: now)
        else {
            return nil
        }

        return formatDuration(interval)
    }

    public var paceTimeLabel: String? {
        guard let state = currentPaceState else { return nil }
        switch state {
        case .ahead:
            return "Time ahead"
        case .onPace:
            return nil
        case .behind:
            return resetCountdownTarget?.kind == .bankedResetExpiry ? nil : "Stoppage time"
        }
    }

    public var paceTimeFields: DurationFields? {
        guard let weeklyWindow = effectiveWeeklyWindow,
              paceTimeLabel != nil else { return nil }
        return durationFields(
            totalSeconds: max(
                0,
                Int(abs(weeklyWindow.paceTimeDeltaInterval(at: now)).rounded(.down))
            )
        )
    }

    public var stoppageEndsAt: Date? {
        guard let weeklyWindow = effectiveWeeklyWindow,
              currentPaceState == .behind,
              resetCountdownTarget?.kind != .bankedResetExpiry else { return nil }
        return now.addingTimeInterval(
            -weeklyWindow.paceTimeDeltaInterval(at: now)
        )
    }

    public var projectedRunoutAt: Date? {
        // The observed consumption rate belongs to the actual server window;
        // target-relative pace guidance uses effectiveWeeklyWindow separately.
        guard paceMetricState == .behind,
              let weeklyWindow = snapshot?.weeklyWindow,
              let projectionAt = nextRefreshAt,
              weeklyWindow.usageRemainingPercent > 0 else { return nil }
        return weeklyWindow.projectedRunoutDate(at: projectionAt)
    }

    public var projectedRunoutCountdownFields: DurationFields? {
        guard let projectedRunoutAt else { return nil }
        return remainingTimeFields(until: projectedRunoutAt)
    }

    public var effectiveWeeklyWindow: UsageWindow? {
        guard let weeklyWindow = snapshot?.weeklyWindow,
              let target = resetCountdownTarget else { return nil }
        return UsageWindow(
            usedPercent: weeklyWindow.usedPercent,
            durationMinutes: weeklyWindow.durationMinutes,
            resetsAt: target.date
        )
    }

    public var timeRemainingLabel: String {
        switch resetCountdownTarget?.kind {
        case .bankedResetExpiry: "To expiry"
        case .manualEstimate: "To estimate"
        default: "Week left"
        }
    }

    public var timelineLabel: String {
        switch resetCountdownTarget?.kind {
        case .bankedResetExpiry: "Expiry"
        case .manualEstimate: "Est."
        default: "Week"
        }
    }

    public var timelineDescription: String {
        switch resetCountdownTarget?.kind {
        case .bankedResetExpiry: "Seven-day scale ending at banked reset expiration"
        case .manualEstimate: "Seven-day scale ending at estimated reset"
        default: "Seven-day usage timeline"
        }
    }

    public var currentPaceDelta: Double? {
        guard let weeklyWindow = effectiveWeeklyWindow else { return nil }
        return weeklyWindow.usageRemainingPercent - weeklyWindow.timeRemainingPercent(at: now)
    }

    /// The headline state at the same one-decimal precision as its displayed value.
    /// Exact timing details continue to use `currentPaceState` so small margins remain visible.
    public var paceMetricState: PaceState? {
        guard let delta = currentPaceDelta else { return nil }
        let displayedDelta = (delta * 10).rounded(.toNearestOrEven) / 10
        if displayedDelta == 0 { return .onPace }
        return displayedDelta > 0 ? .ahead : .behind
    }

    public var currentPaceState: PaceState? {
        guard let delta = currentPaceDelta else { return nil }
        if delta == 0 { return .onPace }
        return delta > 0 ? .ahead : .behind
    }

    public func remainingTimeFields(until date: Date) -> DurationFields {
        durationFields(
            totalSeconds: max(0, Int(date.timeIntervalSince(now).rounded(.down)))
        )
    }

    public var nextRefreshAt: Date? {
        (lastAttempt ?? snapshot?.fetchedAt)?.addingTimeInterval(autoRefreshInterval)
    }

    public var autoRefreshInterval: TimeInterval {
        guard let remaining = snapshot?.weeklyWindow.usageRemainingPercent else { return 60 }
        // Match the whole-percent menu display, including fractional protocol readings.
        return remaining.rounded(.toNearestOrEven) < 2 ? 15 : 60
    }

    func isAutoRefreshDue(at date: Date) -> Bool {
        nextRefreshAt.map { date >= $0 } ?? true
    }

    public var nextRefreshCountdownFields: DurationFields? {
        guard let nextRefreshAt else { return nil }
        let totalSeconds = max(
            0,
            Int(nextRefreshAt.timeIntervalSince(now).rounded(.up))
        )
        return durationFields(totalSeconds: totalSeconds)
    }

    public var resetCountdownTarget: ResetCountdownTarget? {
        guard let naturalResetAt = snapshot?.weeklyWindow.resetsAt else { return nil }
        var target = ResetCountdownTarget(date: naturalResetAt, kind: .natural)

        if let manualResetAt, manualResetAt > now, manualResetAt < target.date {
            target = ResetCountdownTarget(date: manualResetAt, kind: .manualEstimate)
        }

        let earliestBankedResetExpiry = availableBankedResetCredits
            .filter {
                $0.resetType.caseInsensitiveCompare("codexRateLimits") == .orderedSame
            }
            .compactMap(\.expiresAt)
            .min()
        if let earliestExpiry = earliestBankedResetExpiry, earliestExpiry < target.date {
            target = ResetCountdownTarget(date: earliestExpiry, kind: .bankedResetExpiry)
        }

        return target
    }

    public var displayedResetAt: Date? {
        resetCountdownTarget?.date
    }

    public var isManualResetActive: Bool {
        manualResetAt.map { $0 > now } ?? false
    }

    public var availableBankedResetCount: Int {
        max(0, snapshot?.rateLimitResetCredits?.availableCount ?? 0)
    }

    public var availableBankedResetCredits: [RateLimitResetCredit] {
        (snapshot?.rateLimitResetCredits?.credits ?? [])
            .filter { credit in
                credit.status.caseInsensitiveCompare("available") == .orderedSame
                    && (credit.expiresAt.map { $0 > now } ?? true)
            }
            .sorted { left, right in
                switch (left.expiresAt, right.expiresAt) {
                case let (leftDate?, rightDate?):
                    leftDate < rightDate
                case (_?, nil):
                    true
                case (nil, _?):
                    false
                case (nil, nil):
                    left.grantedAt < right.grantedAt
                }
            }
    }

    public var bankedResetCountWithoutDetails: Int {
        max(0, availableBankedResetCount - availableBankedResetCredits.count)
    }

    public func setManualResetAt(_ date: Date) {
        guard date > now else { return }
        manualResetAt = date
        defaults.set(date, forKey: Self.manualResetAtKey)
        if let usageRemainingPercent = snapshot?.weeklyWindow.usageRemainingPercent {
            rememberWeeklyUsageRemainingPercent(usageRemainingPercent)
        }
    }

    public func clearManualReset() {
        manualResetAt = nil
        defaults.removeObject(forKey: Self.manualResetAtKey)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(1, Int((interval / 60).rounded()))
        let days = totalMinutes / (24 * 60)
        let hours = totalMinutes % (24 * 60) / 60
        let minutes = totalMinutes % 60

        return [
            days == 0 ? nil : "\(days)d",
            hours == 0 ? nil : "\(hours)h",
            minutes == 0 ? nil : "\(minutes)m",
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func durationFields(totalSeconds: Int) -> DurationFields {
        DurationFields(
            days: totalSeconds / 86_400,
            hours: totalSeconds % 86_400 / 3_600,
            minutes: totalSeconds % 3_600 / 60,
            seconds: totalSeconds % 60
        )
    }

    private func clearExpiredManualResetIfNeeded() {
        guard let manualResetAt, manualResetAt <= now else { return }
        clearManualReset()
    }

    func applyFreshSnapshot(_ freshSnapshot: PaceSnapshot, now: Date = Date()) {
        if let snapshot, snapshot.accountID == freshSnapshot.accountID,
           freshSnapshot.fetchedAt < snapshot.fetchedAt { return }
        errorMessage = nil
        let usageRemainingPercent = freshSnapshot.weeklyWindow.usageRemainingPercent
        if isManualResetActive,
           let lastWeeklyUsageRemainingPercent,
           lastWeeklyUsageRemainingPercent < 100,
           usageRemainingPercent == 100 {
            clearManualReset()
        }

        let shouldAlert = shouldAlertForCreditConsumption(freshSnapshot)
        let didResetUsage = shouldAlertForUsageReset(freshSnapshot)
        rememberWeeklyUsageRemainingPercent(usageRemainingPercent)
        snapshot = freshSnapshot
        self.now = now
        if shouldAlert { creditConsumptionAlert() }
        if didResetUsage { usageResetAlert() }
        checkBankedResetReminders()
    }

    func checkBankedResetReminders() {
        guard let snapshot else { return }
        // A failed refresh must not silence a known expiration. Label uncertain availability.
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        guard age >= 0 else { return }
        let warnings = availableBankedResetCredits.compactMap { credit -> BankedResetExpiryWarning? in
            guard credit.resetType.caseInsensitiveCompare("codexRateLimits") == .orderedSame,
                  let expiresAt = credit.expiresAt else { return nil }
            let seconds = expiresAt.timeIntervalSince(now)
            guard seconds > 0, seconds <= 12 * 3_600 else { return nil }
            return BankedResetExpiryWarning(creditID: credit.id, expiresAt: expiresAt,
                                           hoursRemaining: Int(ceil(seconds / 3_600)),
                                           availabilityIsLastKnown: errorMessage != nil || age > 2 * autoRefreshInterval)
        }
        let shouldPresent = bankedResetReminders.recordDue(warnings, accountID: snapshot.accountID, now: now)
        bankedResetWarning(warnings, shouldPresent)
    }

    private func shouldAlertForUsageReset(_ fresh: PaceSnapshot) -> Bool {
        // Use the raw percentage: rounding or clamping must not imply a full reset.
        guard (0...100).contains(fresh.weeklyWindow.usedPercent),
              fresh.weeklyWindow.resetsAt > fresh.fetchedAt else { return false }

        let key = fresh.accountID.flatMap { $0.isEmpty ? nil : "\(Self.usageResetReadingKey).\($0)" }
        let stored = key.flatMap { defaults.data(forKey: $0) }
            .flatMap { try? JSONDecoder().decode(UsageResetReading.self, from: $0) }
        let previous = lastUsageResetReading.flatMap {
            $0.accountID == fresh.accountID ? $0.reading : nil
        }
        let baseline = [stored, previous].compactMap { $0 }
            .filter { (0...100).contains($0.usedPercent) }
            .max { $0.fetchedAt < $1.fetchedAt }

        // Do not let duplicate or out-of-order readings rearm the alert.
        if let baseline, fresh.fetchedAt <= baseline.fetchedAt { return false }
        lastUsageResetReading = (fresh.accountID, UsageResetReading(fresh))
        if let key, let data = try? JSONEncoder().encode(UsageResetReading(fresh)) {
            defaults.set(data, forKey: key)
        }
        return fresh.weeklyWindow.usedPercent == 0 && (baseline?.usedPercent ?? 0) > 0
    }

    private func shouldAlertForCreditConsumption(_ fresh: PaceSnapshot) -> Bool {
        guard let accountID = fresh.accountID, !accountID.isEmpty else { return false }
        let alertKey = "\(Self.lastCreditConsumptionAlertKey).\(accountID)"
        if fresh.ordinaryUsageAllowed == true {
            // Only an explicit permission reading confirms that included usage recovered.
            defaults.removeObject(forKey: alertKey)
            return false
        }
        guard fresh.ordinaryUsageAllowed == false,
              fresh.weeklyWindow.usageRemainingPercent == 0,
              fresh.weeklyWindow.resetsAt > fresh.fetchedAt,
              let previous = snapshot,
              previous.accountID == accountID,
              previous.weeklyWindow.resetsAt == fresh.weeklyWindow.resetsAt,
              fresh.fetchedAt > previous.fetchedAt,
              let previousBalance = creditBalanceValue(previous.creditBalance),
              let balance = creditBalanceValue(fresh.creditBalance),
              balance < previousBalance,
              defaults.object(forKey: alertKey) as? Date != fresh.weeklyWindow.resetsAt else {
            return false
        }
        defaults.set(fresh.weeklyWindow.resetsAt, forKey: alertKey)
        return true
    }

    private func creditBalanceValue(_ raw: String?) -> Decimal? {
        guard let raw, UsageCreditBalance.formatted(raw) != nil,
              let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else { return nil }
        return value
    }

    private func rememberWeeklyUsageRemainingPercent(_ usageRemainingPercent: Double) {
        lastWeeklyUsageRemainingPercent = usageRemainingPercent
        defaults.set(
            usageRemainingPercent,
            forKey: Self.lastWeeklyUsageRemainingPercentKey
        )
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastAttempt = Date()
        defer { isRefreshing = false }

        do {
            let freshSnapshot = try await snapshotProvider()
            applyFreshSnapshot(freshSnapshot)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

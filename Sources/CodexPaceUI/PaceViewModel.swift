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
    private static let autoRefreshInterval: TimeInterval = 2 * 60
    private static let manualResetAtKey = "manualResetAt"
    private static let lastWeeklyUsageRemainingPercentKey = "lastWeeklyUsageRemainingPercent"

    @Published public private(set) var snapshot: PaceSnapshot?
    @Published public private(set) var now: Date
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var manualResetAt: Date?

    private var timer: Timer?
    private var lastAttempt: Date?
    private var lastWeeklyUsageRemainingPercent: Double?
    private let defaults: UserDefaults

    public init(
        snapshot: PaceSnapshot? = nil,
        now: Date = Date(),
        pollingEnabled: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        self.snapshot = snapshot
        self.now = now
        self.defaults = defaults
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = Date()
                self.clearExpiredManualResetIfNeeded()
                if self.lastAttempt.map({ self.now.timeIntervalSince($0) >= Self.autoRefreshInterval }) ?? true {
                    await self.refresh()
                }
            }
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
        return "\(time)% / \(usage)%"
    }

    public var paceText: String {
        if currentPaceState == .onPace { return paceMetricLabel }
        guard let paceMetricValue else { return paceMetricLabel }
        return "\(paceMetricLabel) (\(paceMetricValue))"
    }

    public var paceMetricLabel: String {
        if effectiveWeeklyWindow?.usageRemainingPercent == 0 { return "Stopped" }
        switch currentPaceState {
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
              let state = currentPaceState else { return nil }
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
            return "Stoppage time"
        }
    }

    public var paceTimeFields: DurationFields? {
        guard let weeklyWindow = effectiveWeeklyWindow,
              currentPaceState != .onPace else { return nil }
        return durationFields(
            totalSeconds: max(
                0,
                Int(abs(weeklyWindow.paceTimeDeltaInterval(at: now)).rounded(.down))
            )
        )
    }

    public var stoppageEndsAt: Date? {
        guard let weeklyWindow = effectiveWeeklyWindow,
              currentPaceState == .behind else { return nil }
        return now.addingTimeInterval(
            -weeklyWindow.paceTimeDeltaInterval(at: now)
        )
    }

    public var effectiveWeeklyWindow: UsageWindow? {
        guard let weeklyWindow = snapshot?.weeklyWindow else { return nil }
        guard let manualResetAt,
              manualResetAt > now,
              manualResetAt < weeklyWindow.resetsAt else {
            return weeklyWindow
        }
        return UsageWindow(
            usedPercent: weeklyWindow.usedPercent,
            durationMinutes: weeklyWindow.durationMinutes,
            resetsAt: manualResetAt
        )
    }

    public var currentPaceDelta: Double? {
        guard let weeklyWindow = effectiveWeeklyWindow else { return nil }
        return weeklyWindow.usageRemainingPercent - weeklyWindow.timeRemainingPercent(at: now)
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
        (lastAttempt ?? snapshot?.fetchedAt)?.addingTimeInterval(Self.autoRefreshInterval)
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
        let usageRemainingPercent = freshSnapshot.weeklyWindow.usageRemainingPercent
        if isManualResetActive,
           let lastWeeklyUsageRemainingPercent,
           lastWeeklyUsageRemainingPercent < 100,
           usageRemainingPercent == 100 {
            clearManualReset()
        }

        rememberWeeklyUsageRemainingPercent(usageRemainingPercent)
        snapshot = freshSnapshot
        self.now = now
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
            let freshSnapshot = try await Task.detached(priority: .utility) {
                try CodexRateLimitClient().fetch()
            }.value
            applyFreshSnapshot(freshSnapshot)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

import CodexPaceCore
import Foundation

public struct DurationFields: Equatable, Sendable {
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    public init(hours: Int, minutes: Int, seconds: Int) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}

@MainActor
public final class PaceViewModel: ObservableObject {
    private static let autoRefreshInterval: TimeInterval = 2 * 60

    @Published public private(set) var snapshot: PaceSnapshot?
    @Published public private(set) var now: Date
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isRefreshing = false

    private var timer: Timer?
    private var lastAttempt: Date?

    public init(
        snapshot: PaceSnapshot? = nil,
        now: Date = Date(),
        pollingEnabled: Bool = true
    ) {
        self.snapshot = snapshot
        self.now = now

        guard pollingEnabled else { return }
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = Date()
                if self.lastAttempt.map({ self.now.timeIntervalSince($0) >= Self.autoRefreshInterval }) ?? true {
                    await self.refresh()
                }
            }
        }
    }

    public var menuBarText: String {
        guard let snapshot else { return "— / —" }
        let usage = snapshot.weeklyWindow.usageRemainingPercent.formatted(
            .number
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        let time = snapshot.weeklyWindow.timeRemainingPercent(at: now).formatted(
            .number
                .precision(.fractionLength(1))
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        return "\(usage)% / \(time)%"
    }

    public var paceText: String {
        guard let snapshot else { return "Unavailable" }
        let delta = snapshot.paceDeltaPercentagePoints(at: now)
        let formattedDelta = delta.formatted(
            .number.sign(strategy: .always()).precision(.fractionLength(1))
        )
        switch snapshot.paceState(at: now) {
        case .ahead:
            return "Speed up (\(formattedDelta)%)"
        case .onPace:
            return "On pace"
        case .behind:
            return "Slow down (\(formattedDelta)%)"
        }
    }

    public var zeroUsageCatchUpText: String? {
        guard
            let interval = snapshot?.weeklyWindow.zeroUsageCatchUpTimeInterval(at: now)
        else {
            return nil
        }

        return formatDuration(interval)
    }

    public var paceTimeLabel: String? {
        guard let snapshot else { return nil }
        switch snapshot.paceState(at: now) {
        case .ahead:
            return "Time ahead"
        case .onPace:
            return nil
        case .behind:
            return "Stoppage time"
        }
    }

    public var paceTimeFields: DurationFields? {
        guard let snapshot, snapshot.paceState(at: now) != .onPace else { return nil }
        return durationFields(
            totalSeconds: max(
                0,
                Int(abs(snapshot.weeklyWindow.paceTimeDeltaInterval(at: now)).rounded(.down))
            )
        )
    }

    public var stoppageEndsAt: Date? {
        guard let snapshot, snapshot.paceState(at: now) == .behind else { return nil }
        return now.addingTimeInterval(
            -snapshot.weeklyWindow.paceTimeDeltaInterval(at: now)
        )
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

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(1, Int((interval / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    private func durationFields(totalSeconds: Int) -> DurationFields {
        DurationFields(
            hours: totalSeconds / 3_600,
            minutes: totalSeconds % 3_600 / 60,
            seconds: totalSeconds % 60
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
            snapshot = freshSnapshot
            now = Date()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

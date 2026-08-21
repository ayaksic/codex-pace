import CodexPaceCore
import Foundation

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

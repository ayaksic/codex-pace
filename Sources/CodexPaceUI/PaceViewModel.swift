import CodexPaceCore
import Foundation

@MainActor
public final class PaceViewModel: ObservableObject {
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
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = Date()
                if self.lastAttempt.map({ self.now.timeIntervalSince($0) >= 300 }) ?? true {
                    await self.refresh()
                }
            }
        }
    }

    public var menuBarText: String {
        guard let snapshot else { return "—/—" }
        let usage = Int(snapshot.weeklyWindow.usageRemainingPercent.rounded())
        let time = Int(snapshot.weeklyWindow.timeRemainingPercent(at: now).rounded())
        return "\(usage)/\(time)"
    }

    public var paceText: String {
        guard let snapshot else { return "Unavailable" }
        let delta = snapshot.paceDeltaPercentagePoints(at: now)
        switch snapshot.paceState(at: now) {
        case .ahead:
            return "Ahead \(abs(delta).formatted(.number.precision(.fractionLength(1)))) pt"
        case .onPace:
            return "On pace · \(delta.formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))) pt"
        case .behind:
            return "Behind \(abs(delta).formatted(.number.precision(.fractionLength(1)))) pt"
        }
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

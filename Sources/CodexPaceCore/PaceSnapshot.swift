import Foundation

public struct UsageWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let durationMinutes: Int
    public let resetsAt: Date

    public init(usedPercent: Double, durationMinutes: Int, resetsAt: Date) {
        self.usedPercent = usedPercent
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
    }

    public var usageRemainingPercent: Double {
        Self.clamp(100 - usedPercent)
    }

    public func timeRemainingPercent(at date: Date = Date()) -> Double {
        let durationSeconds = Double(durationMinutes) * 60
        guard durationSeconds > 0 else { return 0 }
        return Self.clamp(resetsAt.timeIntervalSince(date) / durationSeconds * 100)
    }

    public func timeRemainingHours(at date: Date = Date()) -> Double {
        max(0, resetsAt.timeIntervalSince(date) / 3_600)
    }

    /// Time required for the remaining-window percentage to fall to the
    /// remaining-usage percentage, assuming usage does not increase.
    public func zeroUsageCatchUpTimeInterval(at date: Date = Date()) -> TimeInterval? {
        let deficitPercentagePoints = timeRemainingPercent(at: date) - usageRemainingPercent
        guard deficitPercentagePoints > 0 else { return nil }
        return deficitPercentagePoints / 100 * Double(durationMinutes) * 60
    }

    private static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}

public enum PaceState: String, Codable, Equatable, Sendable {
    case ahead
    case onPace
    case behind
}

public struct PaceSnapshot: Codable, Equatable, Sendable {
    public let weeklyWindow: UsageWindow
    public let shortWindow: UsageWindow?
    public let fetchedAt: Date
    public let planType: String?
    public let creditBalance: String?

    public init(
        weeklyWindow: UsageWindow,
        shortWindow: UsageWindow? = nil,
        fetchedAt: Date,
        planType: String? = nil,
        creditBalance: String? = nil
    ) {
        self.weeklyWindow = weeklyWindow
        self.shortWindow = shortWindow
        self.fetchedAt = fetchedAt
        self.planType = planType
        self.creditBalance = creditBalance
    }

    public func paceDeltaPercentagePoints(at date: Date = Date()) -> Double {
        weeklyWindow.usageRemainingPercent - weeklyWindow.timeRemainingPercent(at: date)
    }

    public func paceState(at date: Date = Date(), tolerance: Double = 0) -> PaceState {
        let delta = paceDeltaPercentagePoints(at: date)
        if delta == 0 || (tolerance > 0 && abs(delta) < tolerance) {
            return .onPace
        }
        return delta > 0 ? .ahead : .behind
    }
}

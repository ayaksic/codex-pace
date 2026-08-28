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

    /// The time when usage would reach 100% if the average consumption rate
    /// since the window began continued unchanged.
    public func projectedRunoutDate(at date: Date = Date()) -> Date? {
        let durationSeconds = Double(durationMinutes) * 60
        guard durationSeconds > 0, usedPercent > 0, usageRemainingPercent > 0 else {
            return nil
        }

        let windowStartedAt = resetsAt.addingTimeInterval(-durationSeconds)
        let elapsedSeconds = date.timeIntervalSince(windowStartedAt)
        guard elapsedSeconds > 0 else { return nil }

        let remainingSeconds = elapsedSeconds * usageRemainingPercent / usedPercent
        return date.addingTimeInterval(remainingSeconds)
    }

    /// Time required for the remaining-window percentage to fall to the
    /// remaining-usage percentage, assuming usage does not increase.
    public func zeroUsageCatchUpTimeInterval(at date: Date = Date()) -> TimeInterval? {
        let paceTimeDelta = paceTimeDeltaInterval(at: date)
        guard paceTimeDelta < 0 else { return nil }
        return -paceTimeDelta
    }

    /// The time-equivalent pace margin. Positive values are time ahead; negative
    /// values are the time usage would need to stop to return to pace.
    public func paceTimeDeltaInterval(at date: Date = Date()) -> TimeInterval {
        let deltaPercentagePoints = usageRemainingPercent - timeRemainingPercent(at: date)
        return deltaPercentagePoints / 100 * Double(durationMinutes) * 60
    }

    private static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}

public struct RateLimitResetCredit: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let resetType: String
    public let status: String
    public let grantedAt: Date
    public let expiresAt: Date?
    public let title: String?
    public let description: String?

    public init(
        id: String,
        resetType: String,
        status: String,
        grantedAt: Date,
        expiresAt: Date? = nil,
        title: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.resetType = resetType
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
    }
}

public struct RateLimitResetCredits: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let credits: [RateLimitResetCredit]?

    public init(availableCount: Int, credits: [RateLimitResetCredit]? = nil) {
        self.availableCount = availableCount
        self.credits = credits
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
    public let rateLimitResetCredits: RateLimitResetCredits?

    public init(
        weeklyWindow: UsageWindow,
        shortWindow: UsageWindow? = nil,
        fetchedAt: Date,
        planType: String? = nil,
        creditBalance: String? = nil,
        rateLimitResetCredits: RateLimitResetCredits? = nil
    ) {
        self.weeklyWindow = weeklyWindow
        self.shortWindow = shortWindow
        self.fetchedAt = fetchedAt
        self.planType = planType
        self.creditBalance = creditBalance
        self.rateLimitResetCredits = rateLimitResetCredits
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

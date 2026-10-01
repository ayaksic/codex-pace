import Foundation

public enum UsageCreditBalance {
    /// Preserve the server's decimal precision without converting through binary floating point.
    public static func formatted(_ raw: String?) -> String? {
        guard let raw, raw.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?\z"#, options: .regularExpression) != nil else { return nil }
        var value = raw
        let sign = value.first == "-" ? "-" : ""
        if value.first == "-" || value.first == "+" { value.removeFirst() }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        var integer = String(parts[0])
        while integer.count > 1 && integer.first == "0" { integer.removeFirst() }
        var fraction = parts.count == 2 ? String(parts[1]) : ""
        while fraction.last == "0" { fraction.removeLast() }
        let digits = Array(integer)
        let grouped = digits.enumerated().map { index, digit in
            (index > 0 && (digits.count - index) % 3 == 0 ? "," : "") + String(digit)
        }.joined()
        return sign + grouped + (fraction.isEmpty ? "" : "." + fraction)
    }
}

/// A Gregorian calendar date, with no cutoff time or time zone attached.
public struct CreditExpirationNote: Equatable, Sendable {
    public let isoDate: String
    private let year: Int
    private let month: Int
    private let day: Int

    public init?(_ isoDate: String) {
        guard isoDate.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}\z"#, options: .regularExpression) != nil else { return nil }
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard parts[0] > 0,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: parts[0], month: parts[1], day: parts[2]) else { return nil }
        self.isoDate = isoDate
        year = parts[0]; month = parts[1]; day = parts[2]
    }

    public func daysRemaining(at now: Date, timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // Compare civil dates in UTC so DST and skipped local midnights cannot shift the day count.
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: today)!
        let end = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return calendar.dateComponents([.day], from: start, to: end).day!
    }
}

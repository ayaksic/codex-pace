import CodexPaceCore
import Darwin
import Foundation

private struct JSONReport: Encodable {
    let usageRemainingPercent: Double
    let timeRemainingPercent: Double
    let paceDeltaPercentagePoints: Double
    let paceState: PaceState
    let resetAt: Date
    let fetchedAt: Date
    let planType: String?
    let creditBalance: String?
}

private func percent(_ value: Double, places: Int) -> String {
    value.formatted(
        .number
            .precision(.fractionLength(places))
            .locale(Locale(identifier: "en_US"))
    ) + "%"
}

private func paceLabel(for snapshot: PaceSnapshot, at now: Date) -> String {
    let delta = snapshot.paceDeltaPercentagePoints(at: now)
    switch snapshot.paceState(at: now) {
    case .ahead:
        return "Ahead by \(percent(abs(delta), places: 1).dropLast()) points"
    case .onPace:
        return "On pace (\(delta.formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))) points)"
    case .behind:
        return "Behind by \(percent(abs(delta), places: 1).dropLast()) points"
    }
}

let arguments = Set(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    Usage: codex-pace [--json]

    Reports Codex usage remaining against time remaining in the seven-day window.
    Set CODEX_PACE_CODEX_PATH to override the Codex executable location.
    """)
    exit(0)
}

do {
    let now = Date()
    let snapshot = try CodexRateLimitClient().fetch(now: now)

    if arguments.contains("--json") {
        let report = JSONReport(
            usageRemainingPercent: snapshot.weeklyWindow.usageRemainingPercent,
            timeRemainingPercent: snapshot.weeklyWindow.timeRemainingPercent(at: now),
            paceDeltaPercentagePoints: snapshot.paceDeltaPercentagePoints(at: now),
            paceState: snapshot.paceState(at: now),
            resetAt: snapshot.weeklyWindow.resetsAt,
            fetchedAt: snapshot.fetchedAt,
            planType: snapshot.planType,
            creditBalance: snapshot.creditBalance
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        let reset = snapshot.weeklyWindow.resetsAt.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        )
        print("Codex Pace")
        print("Usage left  \(percent(snapshot.weeklyWindow.usageRemainingPercent, places: 0))")
        print("Week left   \(percent(snapshot.weeklyWindow.timeRemainingPercent(at: now), places: 1))")
        print("Pace        \(paceLabel(for: snapshot, at: now))")
        print("Resets      \(reset)")
    }
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data("codex-pace: \(message)\n".utf8))
    exit(1)
}

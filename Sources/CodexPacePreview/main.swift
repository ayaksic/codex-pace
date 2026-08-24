import AppKit
import CodexPaceCore
import CodexPaceUI
import SwiftUI

@main
@MainActor
struct CodexPacePreview {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let outputPath = arguments.first(where: { !$0.hasPrefix("--") })
            ?? "/tmp/codex-pace-preview.png"
        let colorScheme: ColorScheme = arguments.contains("--dark")
            ? .dark
            : .light
        let isLargeDisplay = arguments.contains("--double")
        let hasResetOverride = arguments.contains("--reset-override")
        let hasBankedResets = arguments.contains("--banked-resets")
        let usedPercent = if arguments.contains("--zero-usage") {
            100.0
        } else if arguments.contains("--ahead") {
            17.5
        } else {
            18.0
        }
        let now = Date(timeIntervalSince1970: 1_787_181_600)
        let snapshot = PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: usedPercent,
                durationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 1_787_679_109)
            ),
            fetchedAt: now,
            planType: "pro",
            creditBalance: "0",
            rateLimitResetCredits: hasBankedResets
                ? RateLimitResetCredits(
                    availableCount: 3,
                    credits: [
                        RateLimitResetCredit(
                            id: "preview-reset-1",
                            resetType: "codexRateLimits",
                            status: "available",
                            grantedAt: now.addingTimeInterval(-24 * 3_600),
                            expiresAt: now.addingTimeInterval(11 * 3_600),
                            title: "Rate-limit reset"
                        ),
                        RateLimitResetCredit(
                            id: "preview-reset-2",
                            resetType: "codexRateLimits",
                            status: "available",
                            grantedAt: now.addingTimeInterval(-24 * 3_600),
                            expiresAt: now.addingTimeInterval(35 * 3_600),
                            title: "Rate-limit reset"
                        ),
                    ]
                )
                : nil
        )
        let defaultsSuiteName = "CodexPacePreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let model = PaceViewModel(
            snapshot: snapshot,
            now: now,
            pollingEnabled: false,
            defaults: defaults,
            appBuildInfo: AppBuildInfo(
                version: "1.0.0",
                build: "29",
                sourceRevision: "5e5cebda2253db729256233ba8ceee78ea809db0",
                sourceState: "clean"
            )
        )
        if hasResetOverride {
            model.setManualResetAt(now.addingTimeInterval(11 * 3_600))
        }
        let content = PaceMenuView(
            model: model,
            isLargeDisplay: .constant(isLargeDisplay),
            popOutAction: {}
        )
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard
            let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try png.write(to: URL(fileURLWithPath: outputPath))
        print(outputPath)
    }
}

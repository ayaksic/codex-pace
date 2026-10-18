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
        let showsUsageResetAlert = arguments.contains("--usage-reset-alert")
        let showsWeeklyTimeline = arguments.contains("--timeline")
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
            creditBalance: arguments.contains("--credits") ? "62500.125" : "0",
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
                version: ApplicationVersion.current,
                build: "29",
                sourceRevision: "5e5cebda2253db729256233ba8ceee78ea809db0",
                sourceState: "clean"
            )
        )
        if arguments.contains("--credits") {
            model.setCreditExpirationNote(CreditExpirationNote("2026-12-31")!)
        }
        if hasResetOverride {
            model.setManualResetAt(now.addingTimeInterval(11 * 3_600))
        }
        let content = (arguments.contains("--credit-alert")
            ? AnyView(UsageCreditConsumptionAlertView(dismiss: {}))
            : showsUsageResetAlert ? AnyView(UsageResetAlertView(dismiss: {}))
            : AnyView(PaceMenuView(
            model: model,
            isLargeDisplay: .constant(isLargeDisplay),
            showsWeeklyTimelineInitially: showsWeeklyTimeline,
            showsBankedResetsInitially: arguments.contains("--expanded-resets"),
            maximumHeight: arguments.contains("--short-screen") ? 500 : .infinity,
            popOutAction: {}
        )))
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, colorScheme)
        if arguments.contains("--credit-alert") || showsUsageResetAlert {
            // Native macOS buttons cannot be captured by SwiftUI's ImageRenderer.
            let app = NSApplication.shared
            app.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
            let view = NSHostingView(rootView: content)
            let window = NSPanel(contentRect: NSRect(origin: .zero, size: view.fittingSize),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            window.orderFront(nil)
            defer { window.close() }
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw CocoaError(.fileWriteUnknown)
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try png.write(to: URL(fileURLWithPath: outputPath))
            print(outputPath)
            return
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        if arguments.contains("--constrained-height") {
            renderer.proposedSize = ProposedViewSize(width: nil, height: isLargeDisplay ? 400 : 200)
        }

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

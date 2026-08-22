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
        let usedPercent = arguments.contains("--ahead") ? 17.5 : 18
        let now = Date(timeIntervalSince1970: 1_787_181_600)
        let snapshot = PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: usedPercent,
                durationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 1_787_679_109)
            ),
            fetchedAt: now,
            planType: "pro",
            creditBalance: "0"
        )
        let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false)
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

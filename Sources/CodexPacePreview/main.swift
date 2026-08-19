import AppKit
import CodexPaceCore
import CodexPaceUI
import SwiftUI

@main
@MainActor
struct CodexPacePreview {
    static func main() throws {
        let outputPath = CommandLine.arguments.dropFirst().first ?? "/tmp/codex-pace-preview.png"
        let now = Date(timeIntervalSince1970: 1_787_181_600)
        let snapshot = PaceSnapshot(
            weeklyWindow: UsageWindow(
                usedPercent: 18,
                durationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 1_787_679_109)
            ),
            fetchedAt: now,
            planType: "pro",
            creditBalance: "0"
        )
        let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false)
        let content = PaceMenuView(model: model)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
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

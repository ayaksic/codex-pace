import AppKit
import SwiftUI
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@Test @MainActor func timerDigitsUseOneStableLineHeight() throws {
    var heights = Set<CGFloat>()
    for seconds in 0..<60 {
        let value = String(format: "%02d", seconds)
        let image = try #require(ImageRenderer(content: PaceInkText(value: value, monospacedDigits: true)).nsImage)
        heights.insert(image.size.height)
    }
    #expect(heights.count == 1, "Changing seconds must not change the line height")
}

@Test(arguments: [false, true]) @MainActor
func sixtyTimerTicksKeepEveryLabelAtTheSamePixels(large: Bool) throws {
    let suite = "PaceTextStabilityTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 1_787_181_600)
    let snapshot = PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: 26,
        durationMinutes: 10_080, resetsAt: now.addingTimeInterval(0.968 * 7 * 86_400)),
        fetchedAt: now, creditBalance: "62500.125",
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 1, credits: [
            RateLimitResetCredit(id: "stability-fixture", resetType: "codexRateLimits", status: "available",
                grantedAt: now, expiresAt: now.addingTimeInterval(12 * 86_400))
        ]))
    let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false, defaults: defaults)
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    var labelAreaTop: Int?
    func labelPixels(atTick tick: Int) throws -> Data {
        let renderer = ImageRenderer(content: PaceMenuView(model: model, isLargeDisplay: .constant(large))
            .environment(\.colorScheme, .dark).background(Color.black))
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        if let directory = ProcessInfo.processInfo.environment["CODEX_PACE_STABILITY_DEBUG_DIR"],
           tick == 0 || tick == 2 {
            let path = URL(fileURLWithPath: directory).appendingPathComponent("large-\(large)-tick-\(tick).png")
            try bitmap.representation(using: .png, properties: [:])?.write(to: path)
        }
        let bytes = try #require(bitmap.bitmapData)
        let scale = large ? 4 : 2
        let width = Int(PaceMenuLayout.horizontalPadding + PaceMenuLayout.labelWidth) * scale
        if labelAreaTop == nil {
            // Freeze the label region from the first frame. Animated bars and
            // native toolbar antialiasing are outside this regression's scope.
            let x = Int(PaceMenuLayout.horizontalPadding + PaceMenuLayout.barInset + 20) * scale
            var barBottom: Int?
            for y in 0..<bitmap.pixelsHigh {
                let c = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                if c.redComponent - c.greenComponent > 0.25,
                   c.blueComponent - c.greenComponent > 0.25 { barBottom = y }
            }
            labelAreaTop = try #require(barBottom) + 1
        }
        var pixels = Data()
        for y in labelAreaTop!..<bitmap.pixelsHigh {
            pixels.append(bytes.advanced(by: y * bitmap.bytesPerRow), count: width * bitmap.bitsPerPixel / 8)
        }
        return pixels
    }
    let initial = try labelPixels(atTick: 0)
    var changedSeconds: [Int] = []
    for seconds in 1..<60 {
        model.applyFreshSnapshot(snapshot, now: now.addingTimeInterval(Double(seconds)))
        if try labelPixels(atTick: seconds) != initial { changedSeconds.append(seconds) }
    }
    #expect(changedSeconds.isEmpty,
            "Stationary label pixels changed at seconds \(changedSeconds)")
}

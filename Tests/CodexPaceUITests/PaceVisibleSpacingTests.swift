import AppKit
import SwiftUI
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@Test(arguments: [false, true]) @MainActor
func visibleSpacingMatchesTheRequestedPairsAndGroups(large: Bool) throws {
    let app = NSApplication.shared
    let previousAppearance = app.appearance
    app.appearance = NSAppearance(named: .darkAqua)
    defer { app.appearance = previousAppearance }
    let suite = "PaceVisibleSpacingTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 1_787_181_600)
    let snapshot = PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: 26,
        durationMinutes: 10_080, resetsAt: now.addingTimeInterval(0.968 * 7 * 86_400)),
        fetchedAt: now, creditBalance: "62500.125",
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 1, credits: [
            RateLimitResetCredit(id: "spacing-fixture", resetType: "codexRateLimits", status: "available",
                grantedAt: now, expiresAt: now.addingTimeInterval(12 * 86_400))
        ]))
    let model = PaceViewModel(snapshot: snapshot, now: now, pollingEnabled: false, defaults: defaults)
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    let renderer = ImageRenderer(content: PaceMenuView(model: model, isLargeDisplay: .constant(large))
        .environment(\.colorScheme, .dark)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15)))
    renderer.scale = 2
    let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    let scale: CGFloat = large ? 4 : 2
    func bands(_ test: (CGFloat, CGFloat, CGFloat) -> Bool) -> [ClosedRange<Int>] {
        var result: [ClosedRange<Int>] = []
        for y in 0..<bitmap.pixelsHigh {
            var count = 0
            for x in 0..<bitmap.pixelsWide {
                let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                if test(color.redComponent * 255, color.greenComponent * 255, color.blueComponent * 255) {
                    count += 1
                }
            }
            if count >= 3 {
                if let last = result.last, last.upperBound + 1 == y {
                    result[result.count - 1] = last.lowerBound...y
                } else { result.append(y...y) }
            }
        }
        return result
    }
    let blue = bands { r,g,b in b-r > 25 && b > 75 }
    let purple = bands { r,g,b in r-g > 65 && b-g > 65 }
    let white = bands { r,g,b in min(r,g,b) > 150 && max(r,g,b)-min(r,g,b) < 20 }
    try #require(blue.count == 3)
    try #require(purple.count == 3)
    let header = try #require(white.first)
    let rows = white.filter { $0.lowerBound > purple[2].upperBound }
    try #require(rows.count == 5)
    func check(_ name: String, after: Int, before: Int, expected: CGFloat) {
        let pixels = CGFloat(before - after - 1)
        // One antialiased raster pixel at each visible edge may cross the threshold.
        #expect(abs(pixels - expected * scale) <= 2,
                "\(name): \(pixels / scale) pt, expected \(expected) pt")
    }
    check("top margin", after: -1, before: header.lowerBound, expected: PaceMenuLayout.groupGap)
    check("toolbar to percentages", after: header.upperBound, before: blue[0].lowerBound,
          expected: PaceMenuLayout.groupGap)
    check("percentage to pill", after: blue[0].upperBound, before: blue[1].lowerBound,
          expected: PaceMenuLayout.pairGap)
    check("pills to bars", after: blue[1].upperBound, before: blue[2].lowerBound,
          expected: PaceMenuLayout.groupGap)
    check("between bars", after: blue[2].upperBound, before: purple[2].lowerBound,
          expected: PaceMenuLayout.pairGap)
    check("bars to first row", after: purple[2].upperBound, before: rows[0].lowerBound,
          expected: PaceMenuLayout.groupGap)
    for index in 1..<rows.count {
        check("text rows \(index) and \(index + 1)", after: rows[index - 1].upperBound,
              before: rows[index].lowerBound, expected: PaceMenuLayout.groupGap)
    }
    check("bottom margin", after: rows.last!.upperBound, before: bitmap.pixelsHigh,
          expected: PaceMenuLayout.groupGap)
}

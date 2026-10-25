import AppKit
import Testing
import SwiftUI
import CodexPaceCore
@testable import CodexPaceUI

@Test func primaryPercentagesUseSeravekOrTheSystemFallback() {
    let selected = PaceTypography.metricNativeFont(size: 34)
    if NSFont(name: "Seravek-Medium", size: 34) != nil {
        #expect(selected.familyName == "Seravek")
    }
    let fallback = PaceTypography.metricNativeFont(size: 34, name: "MissingPaceFontForTest")
    #expect(fallback == NSFont.systemFont(ofSize: 34, weight: .medium))
}

@Test func approvedColumnsFitTheNarrowWindowAndShareRowSpacing() {
    #expect(PaceMenuLayout.labelWidth + PaceMenuLayout.countdownWidth + PaceMenuLayout.dateWidth
        + 2 * PaceMenuLayout.columnGap + 2 * PaceMenuLayout.horizontalPadding == PaceMenuLayout.width)
    #expect(PaceMenuLayout.width == 466)
    #expect(PaceMenuLayout.verticalGap == 4)
    #expect(PaceMenuLayout.countdownOffset == 14)
}

@Test @MainActor func countdownDayPrefixDoesNotMoveTheCommonClockBlock() throws {
    func size(_ days: Int) throws -> CGSize {
        let fields = DurationFields(days: days, hours: 8, minutes: 3, seconds: 1)
        return try #require(ImageRenderer(content: AlignedCountdown(fields: fields)).nsImage).size
    }
    #expect(try size(0) == size(13))
}

@Test @MainActor func countdownUnitCellsFitEveryRenderedSuffix() throws {
    for unit in ["d", "h", "m", "s"] {
        let text = Text(unit).font(PaceTypography.rowFont).monospacedDigit().fixedSize()
        let size = try #require(ImageRenderer(content: text).nsImage).size
        #expect(size.width <= PaceMenuLayout.durationUnitWidth,
                "The \(unit) suffix must fit without clipping")
    }
}

@Test @MainActor func opticalTextPreservesCompleteGlyphsWithoutFontLeading() throws {
    func inkSize<V: View>(_ view: V) throws -> CGSize {
        let renderer = ImageRenderer(content: view.foregroundStyle(.white).padding(20))
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return CGSize(width: maxX - minX + 1, height: maxY - minY + 1)
    }
    let samples: [(String, NSFont, CGFloat)] = [
        ("Stop until", PaceTypography.rowNativeFont, 0),
        ("Banked reset", PaceTypography.rowNativeFont, 0),
        ("67d 04h 00m 05s", PaceTypography.rowNativeFont, 0),
        ("Aug 25 · 1:31 PM", PaceTypography.rowNativeFont, 0),
        ("77%", PaceTypography.metricNativeFont(size: 34), 0.5),
        ("100.0%", PaceTypography.metricNativeFont(size: 34), 0.5),
    ]
    for (value, font, tracking) in samples {
        let plain = Text(value).font(Font(font)).tracking(tracking)
        let optical = PaceInkText(value: value, font: font, tracking: tracking)
        #expect(try inkSize(plain) == inkSize(optical))
        let plainHeight = try #require(ImageRenderer(content: plain).nsImage).size.height
        let opticalHeight = try #require(ImageRenderer(content: optical).nsImage).size.height
        #expect(opticalHeight < plainHeight)
    }
}

@Test @MainActor func emptyCountdownCellStillReservesItsColumn() throws {
    let row = PaceColumns { PaceInkText(value: "Credits") } middle: { EmptyView() }
        trailing: { PaceInkText(value: "Set expiration") }
    let size = try #require(ImageRenderer(content: row).nsImage).size
    let populated = PaceColumns { PaceInkText(value: "Credits") }
        middle: { AlignedCountdown(fields: DurationFields(days: 0, hours: 8, minutes: 3, seconds: 1)) }
        trailing: { PaceInkText(value: "Set expiration") }
    #expect(size.width == PaceMenuLayout.width - 2 * PaceMenuLayout.horizontalPadding)
    #expect(size == (try #require(ImageRenderer(content: populated).nsImage).size))
}

@Test func barSeparatorsUseEvenlySpacedPhysicalPixelCenters() {
    #expect(ComparisonBarGeometry.segmentCount == 50)
    for scale: CGFloat in [1, 2, 2.5, 4] {
        let ticks = ComparisonBarGeometry.ticks(width: 434, pixelScale: scale)
        #expect(ticks.count == 49)
        for position in ticks {
            let pixelPosition = position * scale
            #expect(abs(pixelPosition - floor(pixelPosition) - 0.5) < 0.0001)
        }
        let gaps = zip(ticks,ticks.dropFirst()).map { ($1 - $0) * scale }
        #expect((gaps.max()! - gaps.min()!) <= 1.0001)
    }
}

@Test func locallyBundledArealWeightsRegisterWithTheirActualFontNames() {
    // Public builds intentionally omit the licensed assets and use the fallback.
    // When supplied locally, verify that SwiftUI will receive the actual family.
    for weight in PaceTypography.Weight.allCases where PaceTypography.bundledURL(weight) != nil {
        _ = PaceTypography.font(size: 14, weight: weight)
        #expect(PaceTypography.isAvailable(weight))
        #expect(NSFont(name: "ABCAreal-\(weight.rawValue)", size: 14)?.familyName == "ABC Areal")
    }
}

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
    #expect(PaceMenuLayout.rowGap == 6)
    #expect(PaceMenuLayout.countdownOffset == 14)
}

@Test @MainActor func countdownDayPrefixDoesNotMoveTheCommonClockBlock() throws {
    func size(_ days: Int) throws -> CGSize {
        let fields = DurationFields(days: days, hours: 8, minutes: 3, seconds: 1)
        return try #require(ImageRenderer(content: AlignedCountdown(fields: fields)).nsImage).size
    }
    #expect(try size(0) == size(13))
}

@Test @MainActor func emptyCountdownCellStillReservesItsColumn() throws {
    let row = PaceColumns { Text("Credits") } middle: { EmptyView() } trailing: { Text("Set expiration") }
    let size = try #require(ImageRenderer(content: row).nsImage).size
    #expect(size.width == PaceMenuLayout.width - 2 * PaceMenuLayout.horizontalPadding)
    #expect(size.height == PaceMenuLayout.rowHeight)
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

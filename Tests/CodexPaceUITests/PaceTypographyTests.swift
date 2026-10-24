import AppKit
import Testing
@testable import CodexPaceUI

@Test func locallyBundledArealWeightsRegisterWithTheirActualFontNames() {
    // Public builds intentionally omit the licensed assets and use the fallback.
    // When supplied locally, verify that SwiftUI will receive the actual family.
    for weight in PaceTypography.Weight.allCases where PaceTypography.bundledURL(weight) != nil {
        _ = PaceTypography.font(size: 14, weight: weight)
        #expect(PaceTypography.isAvailable(weight))
        #expect(NSFont(name: "ABCAreal-\(weight.rawValue)", size: 14)?.familyName == "ABC Areal")
    }
}

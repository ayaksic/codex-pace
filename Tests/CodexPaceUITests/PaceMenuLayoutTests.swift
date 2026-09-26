import AppKit
import SwiftUI
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@Test @MainActor func expandedResetsPreserveIntrinsicHeightAndRespectScreenLimit() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let suiteName = "PaceMenuLayoutTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = PaceViewModel(
        snapshot: PaceSnapshot(
            weeklyWindow: UsageWindow(usedPercent: 100, durationMinutes: 10_080,
                                     resetsAt: now.addingTimeInterval(3_600)),
            fetchedAt: now,
            rateLimitResetCredits: RateLimitResetCredits(availableCount: 2, credits: (0..<2).map {
                RateLimitResetCredit(id: "fixture-\($0)", resetType: "codexRateLimits",
                                     status: "available", grantedAt: now,
                                     expiresAt: now.addingTimeInterval(Double($0 + 1) * 86_400),
                                     title: "Rate-limit reset")
            })
        ), now: now, pollingEnabled: false, defaults: defaults
    )
    for large in [false, true] {
        func size(expanded: Bool, height: CGFloat?, maximumHeight: CGFloat = .infinity) throws -> CGSize {
            let renderer = ImageRenderer(content: PaceMenuView(
                model: model, isLargeDisplay: .constant(large),
                showsBankedResetsInitially: expanded, maximumHeight: maximumHeight
            ))
            renderer.proposedSize = ProposedViewSize(width: nil, height: height)
            return try #require(renderer.nsImage).size
        }
        let collapsed = try size(expanded: false, height: nil)
        let expanded = try size(expanded: true, height: nil)
        let constrained = try size(expanded: true, height: 0)
        #expect(expanded.height > collapsed.height)
        #expect(constrained == expanded)
        let bounded = try size(expanded: true, height: nil, maximumHeight: collapsed.height)
        #expect(bounded.height == collapsed.height)
        #expect(bounded.width == expanded.width)
    }
}

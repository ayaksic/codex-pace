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

@Test @MainActor func nativeHostedContentResizesWhenResetRowsArrive() throws {
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

    let expandedSnapshot = try #require(model.snapshot)
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: expandedSnapshot.weeklyWindow, fetchedAt: now), now: now)
    let sizer = PaceWindowSizer()
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 412, height: 240),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    var measurements: [CGSize] = []
    let content = PaceMenuView(model: model, isLargeDisplay: .constant(false),
                              showsBankedResetsInitially: true, maximumHeight: 700)
        .onPreferenceChange(PaceContentSizeKey.self) { size in
            measurements.append(size)
            DispatchQueue.main.async { sizer.updateContentSize(size) }
        }
    window.contentView = NSHostingView(rootView: content)
    sizer.window = window
    func settle() {
        for _ in 0..<20 {
            window.contentView?.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
    settle()
    let collapsedHeight = window.contentLayoutRect.height
    let measurementsBefore = measurements.count
    withAnimation { model.applyFreshSnapshot(expandedSnapshot, now: now) }
    settle()
    #expect(measurements.count > measurementsBefore)
    #expect(window.contentLayoutRect.height > collapsedHeight + 30)
    #expect(abs(window.contentLayoutRect.height - (measurements.last?.height ?? 0)) < 1)
    withAnimation {
        model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: expandedSnapshot.weeklyWindow, fetchedAt: now), now: now)
    }
    settle()
    #expect(abs(window.contentLayoutRect.height - collapsedHeight) < 1)
    #expect(abs(window.contentLayoutRect.height - (measurements.last?.height ?? 0)) < 1)
}

@Test func emptySiblingPreferenceDoesNotEraseMeasuredContentSize() {
    var size = CGSize(width: 412, height: 313)
    PaceContentSizeKey.reduce(value: &size, nextValue: { .zero })
    #expect(size == CGSize(width: 412, height: 313))
    PaceContentSizeKey.reduce(value: &size, nextValue: { CGSize(width: 412, height: 233) })
    #expect(size == CGSize(width: 412, height: 233))
}

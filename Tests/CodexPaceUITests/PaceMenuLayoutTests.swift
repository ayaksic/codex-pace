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

@Test(arguments: [false, true]) @MainActor
func nativeHostedContentResizesWhenResetRowsArrive(menuPanel: Bool) throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let suiteName = "PaceMenuLayoutTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = PaceViewModel(
        snapshot: PaceSnapshot(
            weeklyWindow: UsageWindow(usedPercent: 100, durationMinutes: 10_080,
                                     resetsAt: now.addingTimeInterval(3_600)),
            fetchedAt: now,
            creditBalance: "62500",
            rateLimitResetCredits: RateLimitResetCredits(availableCount: 2, credits: (0..<2).map {
                RateLimitResetCredit(id: "fixture-\($0)", resetType: "codexRateLimits",
                                     status: "available", grantedAt: now,
                                     expiresAt: now.addingTimeInterval(Double($0 + 1) * 86_400),
                                     title: "Rate-limit reset")
            })
        ), now: now, pollingEnabled: false, defaults: defaults
    )

    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    let expandedSnapshot = try #require(model.snapshot)
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: expandedSnapshot.weeklyWindow, fetchedAt: now), now: now)
    let sizer = PaceWindowSizer()
    let initialFrame = CGRect(x: 100, y: 100, width: 412, height: 240)
    let window: NSWindow = menuPanel
        ? NSPanel(contentRect: initialFrame, styleMask: [.borderless, .nonactivatingPanel],
                  backing: .buffered, defer: false)
        : NSWindow(contentRect: initialFrame, styleMask: [.titled, .resizable],
                   backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    var measurements: [CGSize] = []
    let content = PaceMenuView(model: model, isLargeDisplay: menuPanel ? nil : .constant(false),
                              showsBankedResetsInitially: true, maximumHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onPreferenceChange(PaceContentSizeKey.self) { size in
            measurements.append(size)
            DispatchQueue.main.async { sizer.updateContentSize(size) }
        }
    window.contentView = NSHostingView(rootView: content)
    sizer.window = window
    func settle() {
        for _ in 0..<60 {
            window.contentView?.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
    settle()
    let collapsedHeight = window.contentLayoutRect.height
    let measurementsBefore = measurements.count
    withAnimation { model.applyFreshSnapshot(expandedSnapshot, now: now) }
    settle()
    if menuPanel, let outputPath = ProcessInfo.processInfo.environment["CODEX_PACE_PANEL_RENDER_PATH"],
       let view = window.contentView,
       let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: outputPath))
    }
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

@Test @MainActor func creditNoteLayoutsScaleAndStayBounded() throws {
    let suite = "CreditLayoutTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 1_787_181_600)
    let model = PaceViewModel(snapshot: PaceSnapshot(
        weeklyWindow: UsageWindow(usedPercent: 20, durationMinutes: 10_080,
                                 resetsAt: now.addingTimeInterval(86_400)),
        fetchedAt: now, creditBalance: "62500.125"), now: now, pollingEnabled: false, defaults: defaults)
    func size(_ large: Bool, bounded: Bool = false) throws -> CGSize {
        try #require(ImageRenderer(content: PaceMenuView(model: model,
            isLargeDisplay: .constant(large), maximumHeight: bounded ? 400 : .infinity)).nsImage).size
    }
    let withoutNote = try size(false)
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    let single = try size(false)
    let double = try size(true)
    #expect(single.height > withoutNote.height)
    #expect(single.width == 412)
    #expect(double.width == single.width * 2)
    #expect(abs(double.height - single.height * 2) < 1)
    #expect(try size(true, bounded: true).height == 400)
    model.removeCreditExpirationNote()
    #expect(try size(false) == withoutNote)
    let editor = try #require(ImageRenderer(content: CreditExpirationEditor(model: model)).nsImage)
    #expect(editor.size.width == 380)
}

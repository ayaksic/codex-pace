import AppKit
import SwiftUI
import Testing
import CodexPaceCore
@testable import CodexPaceUI

@Test @MainActor func bankedResetRowsAreAlwaysVisibleAndRespectScreenLimit() throws {
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
    let withResets = try #require(model.snapshot)
    for large in [false, true] {
        func size(height: CGFloat?, maximumHeight: CGFloat = .infinity) throws -> CGSize {
            let renderer = ImageRenderer(content: PaceMenuView(
                model: model, isLargeDisplay: .constant(large),
                maximumHeight: maximumHeight
            ))
            renderer.proposedSize = ProposedViewSize(width: nil, height: height)
            return try #require(renderer.nsImage).size
        }
        model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: withResets.weeklyWindow, fetchedAt: now), now: now)
        let collapsed = try size(height: nil)
        model.applyFreshSnapshot(withResets, now: now)
        let expanded = try size(height: nil)
        let constrained = try size(height: 0)
        #expect(expanded.height > collapsed.height)
        #expect(constrained == expanded)
        let bounded = try size(height: nil, maximumHeight: collapsed.height)
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
                              maximumHeight: 700)
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
            isLargeDisplay: .constant(large), maximumHeight: bounded ? 100 : .infinity)).nsImage).size
    }
    let withoutNote = try size(false)
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    let single = try size(false)
    let double = try size(true)
    #expect(single.height == withoutNote.height) // Expiration stays on the existing credit row.
    #expect(single.width == PaceMenuLayout.width)
    #expect(double.width == single.width * 2)
    #expect(abs(double.height - single.height * 2) < 1)
    #expect(try size(true, bounded: true).height == 100)
    model.removeCreditExpirationNote()
    #expect(try size(false) == withoutNote)
    let editor = try #require(ImageRenderer(content: CreditExpirationEditor(model: model)).nsImage)
    #expect(editor.size.width == 380)
}

@Test @MainActor func mainWindowScalesToArbitraryWidthsAndScrollsAtChosenHeight() async throws {
    let suite = "ResizablePaceWindowTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let weeklyWindow = UsageWindow(usedPercent: 100, durationMinutes: 10_080,
                                  resetsAt: now.addingTimeInterval(6 * 86_400))
    let model = PaceViewModel(snapshot: PaceSnapshot(weeklyWindow: weeklyWindow, fetchedAt: now),
                              now: now, pollingEnabled: false, defaults: defaults)
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 620, height: 600),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    var measuredSize = CGSize.zero
    var largePreset = false
    window.contentView = NSHostingView(rootView: PaceMainWindowView(
        model: model, isLargeDisplay: Binding(get: { largePreset }, set: { largePreset = $0 }))
        .background(Color(nsColor: .windowBackgroundColor))
        .onPreferenceChange(PaceContentSizeKey.self) { measuredSize = $0 })
    func settle() async throws {
        for _ in 0..<30 {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    try await settle()
    #expect(window.frame.width == PaceMenuLayout.width)
    let initialHeight = window.contentLayoutRect.height
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: weeklyWindow, fetchedAt: now,
        creditBalance: "62500.125", rateLimitResetCredits: RateLimitResetCredits(
            availableCount: 1, credits: [RateLimitResetCredit(id: "fixture", resetType: "codexRateLimits",
                status: "available", grantedAt: now, expiresAt: now.addingTimeInterval(5 * 86_400))])), now: now)
    model.setCreditExpirationNote(try #require(CreditExpirationNote("2026-12-31")))
    try await settle()
    #expect(window.contentLayoutRect.height == initialHeight)

    for size in [CGSize(width: 480, height: 360), CGSize(width: 850, height: 650),
                 CGSize(width: 1050, height: 360)] {
        window.setContentSize(size)
        try await settle()
        #expect(window.contentLayoutRect.size == size)
        #expect(abs(measuredSize.width - size.width) < 1)
        #expect(measuredSize.height <= size.height)
        let scrollView = findScrollView(in: try #require(window.contentView))
        let scroll = try #require(scrollView)
        #expect(scroll.hasVerticalScroller)
        if size.width == 1050 {
            let document = try #require(scroll.documentView)
            #expect(document.frame.height > scroll.contentSize.height)
            scroll.contentView.scroll(to: CGPoint(x: 0, y: document.frame.height - scroll.contentSize.height))
            scroll.reflectScrolledClipView(scroll.contentView)
            #expect(scroll.contentView.bounds.minY > 0)
            #expect(scroll.contentView.bounds.maxY <= document.frame.height + 1)
        }
        if let directory = ProcessInfo.processInfo.environment["CODEX_PACE_RESIZE_RENDER_DIRECTORY"],
           let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to:
                URL(fileURLWithPath: directory).appendingPathComponent("resize-\(Int(size.width)).png"))
        }
    }
    largePreset = true
    model.objectWillChange.send()
    try await settle()
    #expect(window.frame.width == PaceMenuLayout.width * 2)
    largePreset = false
    model.objectWillChange.send()
    try await settle()
    #expect(window.frame.width == PaceMenuLayout.width)
    #expect(abs(window.contentLayoutRect.height - measuredSize.height) < 1)
}

@MainActor private func findScrollView(in view: NSView) -> NSScrollView? {
    if let scroll = view as? NSScrollView { return scroll }
    return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
}

@Test(arguments: [false, true]) @MainActor
func firstReadingFitsStartupWindowOnceUnlessUserAlreadyResized(manualResize: Bool) async throws {
    let suite = "PaceStartupSizingTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let model = PaceViewModel(now: now, pollingEnabled: false, defaults: defaults)
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 466, height: PaceMenuLayout.minimumWindowHeight),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    window.contentView = NSHostingView(rootView: PaceMainWindowView(model: model, isLargeDisplay: .constant(false)))
    func settle() async throws {
        for _ in 0..<30 {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    try await settle()
    if manualResize { window.setContentSize(CGSize(width: 560, height: 300)); try await settle() }
    let initialSize = window.contentLayoutRect.size
    let snapshot = PaceSnapshot(weeklyWindow: UsageWindow(usedPercent: 100, durationMinutes: 10_080,
        resetsAt: now.addingTimeInterval(86_400)), fetchedAt: now, creditBalance: "62500",
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 2, credits: (0..<2).map {
            RateLimitResetCredit(id: "startup-fixture-\($0)", resetType: "codexRateLimits", status: "available",
                grantedAt: now, expiresAt: now.addingTimeInterval(Double($0 + 2) * 86_400))
        }))
    model.applyFreshSnapshot(snapshot, now: now)
    try await settle()
    if manualResize { #expect(window.contentLayoutRect.size == initialSize) }
    else {
        #expect(window.frame.width == PaceMenuLayout.width)
        #expect(window.contentLayoutRect.height > initialSize.height)
        let host = try #require(window.contentView)
        let scroll = try #require(findScrollView(in: host))
        let document = try #require(scroll.documentView)
        #expect(document.frame.height <= scroll.contentSize.height + 1)
    }
    let fittedSize = window.contentLayoutRect.size
    model.applyFreshSnapshot(PaceSnapshot(weeklyWindow: snapshot.weeklyWindow, fetchedAt: now), now: now)
    try await settle()
    #expect(window.contentLayoutRect.size == fittedSize)
}

import AppKit
import Testing
@testable import CodexPaceUI

@Test @MainActor func nativeWindowGrowsForRowsAndKeepsTitleBarOutsideContent() {
    for fullSizeContent in [false, true] {
        var style: NSWindow.StyleMask = [.titled, .closable, .resizable]
        if fullSizeContent { style.insert(.fullSizeContentView) }
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 412, height: 260),
                              styleMask: style, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let sizer = PaceWindowSizer()
        sizer.window = window

        for size in [CGSize(width: 412, height: 260), CGSize(width: 412, height: 340),
                     CGSize(width: 824, height: 680), CGSize(width: 412, height: 340),
                     CGSize(width: 412, height: 260)] {
            sizer.updateContentSize(size)
            #expect(abs(window.contentLayoutRect.height - size.height) < 0.5)
            #expect(abs(window.frame.width - size.width) < 0.5)
            #expect(window.contentAspectRatio == .zero)
            let frame = window.frame
            sizer.updateContentSize(size)
            #expect(window.frame == frame)
        }
    }
}

@Test @MainActor func rowChangesFitHeightAndRebaseManualResizeRatio() {
    for fullSizeContent in [false, true] {
        var style: NSWindow.StyleMask = [.titled, .closable, .resizable]
        if fullSizeContent { style.insert(.fullSizeContentView) }
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 620, height: 400),
                              styleMask: style, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let sizer = PaceWindowSizer(allowsManualResize: true)
        // Leave room to grow downward without reaching the Dock boundary.
        window.setFrameTopLeftPoint(CGPoint(x: window.frame.minX,
            y: window.screen?.visibleFrame.maxY ?? 900))
        let initialFrame = window.frame
        sizer.window = window
        #expect(window.contentAspectRatio == window.contentRect(forFrameRect: initialFrame).size)
        sizer.updateContentSize(CGSize(width: 620, height: 400))
        #expect(window.frame == initialFrame)

        for height: CGFloat in [480, 320, 400] {
            let previousTop = window.frame.maxY
            sizer.updateContentSize(CGSize(width: 620, height: height))
            #expect(window.frame.width == 620)
            #expect(abs(window.contentLayoutRect.height - height) < 0.5)
            #expect(window.frame.maxY == previousTop)
            #expect(window.contentAspectRatio == window.contentRect(forFrameRect: window.frame).size)
            let fittedFrame = window.frame
            // Equivalent measurements at another scale must not resize again.
            sizer.updateContentSize(CGSize(width: 1240, height: height * 2))
            #expect(window.frame == fittedFrame)
        }

        for scale: CGFloat in [1, 2, 1] {
            sizer.usePreset(scale: scale)
            let presetFrame = window.frame
            #expect(window.frame.width == PaceMenuLayout.width * scale)
            #expect(window.contentAspectRatio == window.contentRect(forFrameRect: presetFrame).size)
            sizer.updateContentSize(CGSize(width: 620, height: 400))
            #expect(window.frame == presetFrame)
        }

        // A preset must also establish the lock when no frame change is needed.
        window.contentResizeIncrements = CGSize(width: 1, height: 1)
        let presetFrame = window.frame
        sizer.usePreset(scale: 1)
        #expect(window.frame == presetFrame)
        #expect(window.contentAspectRatio == window.contentRect(forFrameRect: presetFrame).size)
    }
}

@Test @MainActor func nativeWindowAcceptsMeasurementBeforeAttachment() {
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 412, height: 260),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let sizer = PaceWindowSizer()
    sizer.updateContentSize(CGSize(width: 412, height: 340))
    sizer.window = window
    #expect(abs(window.contentLayoutRect.height - 340) < 0.5)
}

@Test @MainActor func rowChangesPreserveManualWidthAndClampToScreen() throws {
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 620, height: 400),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let sizer = PaceWindowSizer(allowsManualResize: true)
    sizer.window = window
    sizer.updateContentSize(CGSize(width: 620, height: 400))
    window.setContentSize(CGSize(width: 850, height: 550))
    let manualFrame = window.frame
    sizer.updateContentSize(CGSize(width: 850, height: 400 * 850 / 620))
    #expect(window.frame == manualFrame)

    // New rows measured at an old width fit using the current width.
    sizer.updateContentSize(CGSize(width: 620, height: 450))
    #expect(window.frame.width == 850)
    #expect(abs(window.contentLayoutRect.height - ceil(450 * 850 / 620)) < 0.5)

    let screen = try #require(window.screen)
    sizer.updateContentSize(CGSize(width: 620, height: 10_000))
    #expect(window.frame.width == 850)
    #expect(window.frame.height <= screen.visibleFrame.height)
    #expect(window.frame.minY >= screen.visibleFrame.minY)
    #expect(window.frame.maxY <= screen.visibleFrame.maxY)
    sizer.updateContentSize(CGSize(width: 620, height: 300))
    #expect(window.frame.width == 850)
    #expect(abs(window.contentLayoutRect.height - ceil(300 * 850 / 620)) < 0.5)
}

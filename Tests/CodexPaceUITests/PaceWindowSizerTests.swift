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

@Test @MainActor func manualResizeLocksContentRatioUntilAnExplicitPreset() {
    for fullSizeContent in [false, true] {
        var style: NSWindow.StyleMask = [.titled, .closable, .resizable]
        if fullSizeContent { style.insert(.fullSizeContentView) }
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 620, height: 400),
                              styleMask: style, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let sizer = PaceWindowSizer(allowsManualResize: true)
        let initialFrame = window.frame
        sizer.window = window
        let initialRatio = window.contentAspectRatio
        #expect(initialRatio == window.contentRect(forFrameRect: initialFrame).size)
        #expect(window.frame == initialFrame)

        // Loading, extra rows, and stale drag measurements must not alter the
        // chosen frame or unlock/rebase its ratio.
        for size in [CGSize(width: 620, height: 250), CGSize(width: 620, height: 600),
                     CGSize(width: 850, height: 700)] {
            sizer.updateContentSize(size)
            sizer.window = window
            #expect(window.frame == initialFrame)
            #expect(window.contentAspectRatio == initialRatio)
        }

        for scale: CGFloat in [1, 2, 1] {
            sizer.usePreset(scale: scale)
            let presetFrame = window.frame
            let presetRatio = window.contentAspectRatio
            #expect(presetRatio == window.contentRect(forFrameRect: presetFrame).size)
            #expect(presetRatio.width / presetRatio.height != initialRatio.width / initialRatio.height)
            sizer.updateContentSize(CGSize(width: 850, height: 700))
            #expect(window.frame == presetFrame)
            #expect(window.contentAspectRatio == presetRatio)
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

@Test @MainActor func manualResizePreservesFrameAcrossContentUpdatesUntilPresetIsSelected() {
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 620, height: 500),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let sizer = PaceWindowSizer(allowsManualResize: true)
    sizer.window = window
    sizer.updateContentSize(CGSize(width: 620, height: 500))

    window.setContentSize(CGSize(width: 850, height: 400))
    let manuallySizedFrame = window.frame
    sizer.updateContentSize(CGSize(width: 850, height: 700))
    #expect(window.frame == manuallySizedFrame)

    sizer.usePreset(scale: 1)
    #expect(window.frame.width == PaceMenuLayout.width)
    let presetFrame = window.frame
    sizer.updateContentSize(CGSize(width: 620, height: 520))
    #expect(window.frame == presetFrame)
    sizer.usePreset(scale: 2)
    #expect(window.frame.width == PaceMenuLayout.width * 2)
    #expect(window.contentLayoutRect.height <= 1040)
    let doubleFrame = window.frame
    // Out-of-date measurements can arrive after a preset or a live drag. They
    // must never pull the main window back to a previously measured width.
    for size in [CGSize(width: 620, height: 520), CGSize(width: 1240, height: 1040),
                 CGSize(width: 620, height: 500), CGSize(width: 850, height: 700)] {
        sizer.updateContentSize(size)
        #expect(window.frame == doubleFrame)
    }
}

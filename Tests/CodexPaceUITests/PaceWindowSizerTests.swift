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
            let frame = window.frame
            sizer.updateContentSize(size)
            #expect(window.frame == frame)
        }
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
    #expect(window.frame.width == 620)
    let presetFrame = window.frame
    sizer.updateContentSize(CGSize(width: 620, height: 520))
    #expect(window.frame == presetFrame)
    sizer.usePreset(scale: 2)
    #expect(window.frame.width == 1240)
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

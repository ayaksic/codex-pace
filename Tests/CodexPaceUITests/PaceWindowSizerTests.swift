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

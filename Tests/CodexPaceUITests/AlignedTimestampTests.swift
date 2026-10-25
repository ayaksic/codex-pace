import AppKit
import SwiftUI
import Testing
@testable import CodexPaceUI

private func timestampSamples() -> [Date] {
    let calendar = Calendar(identifier: .gregorian)
    return (1...12).flatMap { month in
        [6, 28].flatMap { day in
            [0, 6, 11, 12, 23].compactMap { hour in
                calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: 59))
            }
        }
    }
}

@Test @MainActor func timestampFieldsFitWithoutClippingAcrossMonthsAndHourWidths() throws {
    #expect(PaceMenuLayout.timestampDateWidth + PaceMenuLayout.timestampSeparatorWidth
        + PaceMenuLayout.timestampTimeWidth + 2 * PaceMenuLayout.timestampGap == PaceMenuLayout.dateWidth)
    let samples = timestampSamples().map { AlignedTimestamp(date: $0) }
    for text in Set(samples.map(\.dateText)) {
        let image = try #require(ImageRenderer(content: PaceInkText(value: text, monospacedDigits: true)).nsImage)
        #expect(image.size.width <= PaceMenuLayout.timestampDateWidth, "Date must fit: \(text)")
    }
    for text in Set(samples.map(\.timeText)) {
        let image = try #require(ImageRenderer(content: PaceInkText(value: text, monospacedDigits: true)).nsImage)
        #expect(image.size.width <= PaceMenuLayout.timestampTimeWidth, "Time must fit: \(text)")
    }
}

@Test(arguments: [false, true]) @MainActor
func timestampDotsStayAtIdenticalPixelsForEveryDateAndTime(large: Bool) throws {
    let scale = large ? 4 : 2
    let start = Int(8 + PaceMenuLayout.timestampDateWidth + PaceMenuLayout.timestampGap) * scale
    let end = start + Int(PaceMenuLayout.timestampSeparatorWidth) * scale
    var reference: Set<Int>?
    for date in timestampSamples() {
        let renderer = ImageRenderer(content: AlignedTimestamp(date: date)
            .foregroundStyle(.white).padding(8).background(Color.black))
        renderer.scale = CGFloat(scale)
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        var dot: Set<Int> = []
        for y in 0..<bitmap.pixelsHigh {
            for x in start..<end {
                let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                if min(color.redComponent, color.greenComponent, color.blueComponent) > 0.6 {
                    dot.insert(y * bitmap.pixelsWide + x)
                }
            }
        }
        try #require(!dot.isEmpty)
        if reference == nil { reference = dot }
        #expect(dot == reference, "The middle dot must remain stationary for every date and time")
    }
}

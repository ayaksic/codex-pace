import Foundation
import SwiftUI

/// Date and time widths never move the shared middle-dot position.
struct AlignedTimestamp: View {
    let date: Date

    var dateText: String {
        date.formatted(.dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US_POSIX")))
    }

    var timeText: String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            .locale(Locale(identifier: "en_US_POSIX")))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PaceMenuLayout.timestampGap) {
            PaceInkText(value: dateText, monospacedDigits: true).fixedSize()
                .frame(width: PaceMenuLayout.timestampDateWidth, alignment: .trailing)
            PaceInkText(value: "·").fixedSize()
                .frame(width: PaceMenuLayout.timestampSeparatorWidth)
            PaceInkText(value: timeText, monospacedDigits: true).fixedSize()
                .frame(width: PaceMenuLayout.timestampTimeWidth, alignment: .leading)
        }
        .frame(width: PaceMenuLayout.dateWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dateText), \(timeText)")
    }
}

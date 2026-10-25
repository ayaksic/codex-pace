import AppKit
import CoreText
import SwiftUI

/// Fonts are registered only for this process, never installed on the Mac.
public enum PaceTypography {
    static var rowNativeFont: NSFont { .systemFont(ofSize: 14, weight: .medium) }
    static let rowFont = Font.system(size: 14, weight: .medium)
    static let rowLineReference = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789:.,·%-+—"
    static let metricLineReference = "+-0123456789.%—"
    static let rowLineMetrics = PaceTextLineMetrics(font: rowNativeFont, reference: rowLineReference)

    static func metricNativeFont(size: CGFloat, name: String = "Seravek-Medium") -> NSFont {
        NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: .medium)
    }

    public static func metricFont(size: CGFloat) -> Font {
        Font(metricNativeFont(size: size))
    }
    public enum Weight: String, CaseIterable {
        case regular = "Regular"
        case medium = "Medium"
        case bold = "Bold"
    }

    private static let registered: Void = {
        for weight in Weight.allCases {
            if let url = bundledURL(weight) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    static func bundledURL(_ weight: Weight) -> URL? {
        Bundle.module.url(forResource: "ABCAreal-\(weight.rawValue)",
                          withExtension: "ttf", subdirectory: "Fonts")
    }

    public static func font(size: CGFloat, weight: Weight = .regular) -> Font {
        _ = registered
        let name = "ABCAreal-\(weight.rawValue)"
        guard let native = NSFont(name: name, size: size) else {
            return .system(size: size, weight: systemWeight(weight))
        }
        return Font(native)
    }

    static func isAvailable(_ weight: Weight) -> Bool {
        _ = registered
        return NSFont(name: "ABCAreal-\(weight.rawValue)", size: 13) != nil
    }

    private static func systemWeight(_ weight: Weight) -> Font.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .bold: .bold
        }
    }
}

/// Shared spacing sources keep peer elements equally separated at either scale.
enum PaceMenuLayout {
    static let width: CGFloat = 466
    // Tight pairs share one gap; visible group and row edges share the other.
    static let pairGap: CGFloat = 4
    static let groupGap: CGFloat = 11
    static let rowHeight = PaceTypography.rowLineMetrics.height
    static let barHeight: CGFloat = 10
    static let comparisonHeight = 2 * barHeight + pairGap
    static let minimumWindowHeight: CGFloat = 120
    static let horizontalPadding: CGFloat = 13
    static let barInset: CGFloat = 3
    static let columnGap: CGFloat = 10
    static let labelWidth: CGFloat = 118
    static let countdownWidth: CGFloat = 170
    static let dateWidth: CGFloat = 132
    static let timestampDateWidth: CGFloat = 50
    static let timestampSeparatorWidth: CGFloat = 5
    static let timestampTimeWidth: CGFloat = 67
    static let timestampGap: CGFloat = 5
    static let durationNumberWidth: CGFloat = 18
    // The system-medium "m" needs 13 points, including layout rounding.
    static let durationUnitWidth: CGFloat = 13
    static let durationPartWidth = durationNumberWidth + durationUnitWidth
    static let durationGap: CGFloat = 6
    static let countdownOffset: CGFloat = 14
}

/// A fixed font reference keeps line heights and baselines independent of the
/// current digits. Half-point geometry stays on a stable grid at 1× and 2×.
struct PaceTextLineMetrics: Sendable {
    let top: CGFloat
    let bottom: CGFloat
    var height: CGFloat { top - bottom }

    init(font: NSFont, reference: String) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: reference, attributes: [.font: font]
        ))
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        top = (ink.maxY * 2).rounded() / 2
        bottom = top - (ink.height * 2).rounded() / 2
    }
}

/// Keep complete glyphs and normal font sizes, with stable optical line metrics.
/// Text is never clipped to the line box.
struct PaceInkText: View {
    let value: String
    var font: NSFont = PaceTypography.rowNativeFont
    var tracking: CGFloat = 0
    var monospacedDigits = false
    var lineReference: String = PaceTypography.rowLineReference

    var body: some View {
        let metrics = PaceTextLineMetrics(font: font, reference: lineReference)
        PaceTextInkLayout(top: metrics.top, bottom: metrics.bottom) {
            Text(value).font(monospacedDigits ? Font(font).monospacedDigit() : Font(font))
                .tracking(tracking).lineLimit(1)
        }
    }
}

/// SF Symbols include a small clear inset in their native image bounds.
/// Exclude it from stack measurement while retaining the full controls and icons.
struct PaceToolbarLayout: Layout {
    private let opticalInset: CGFloat = 1.25

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews[0].sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: size.height - 2 * opticalInset)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY - opticalInset),
                          anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

private struct PaceTextInkLayout: Layout {
    let top: CGFloat
    let bottom: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews[0].sizeThatFits(proposal)
        return CGSize(width: size.width, height: max(0, top - bottom))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let textProposal = ProposedViewSize(width: bounds.width, height: nil)
        let dimensions = subviews[0].dimensions(in: textProposal)
        subviews[0].place(at: CGPoint(x: bounds.minX,
            y: bounds.minY + top - dimensions[.firstTextBaseline]),
            anchor: .topLeading, proposal: textProposal)
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect,
                           proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGFloat? {
        guide == .firstTextBaseline || guide == .lastTextBaseline ? top : nil
    }
}

enum PaceColors {
    static let usage = adaptive(light: 0x0074E8, dark: 0x0A84FF)
    static let time = adaptive(light: 0xBD26D0, dark: 0xD72FE9)
    static let secondary = adaptive(light: 0x686A72, dark: 0xACADB5)
    static let warning = adaptive(light: 0xA94A00, dark: 0xFFAB56)
    static let success = adaptive(light: 0x277544, dark: 0x71CB8C)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

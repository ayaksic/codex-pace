import AppKit
import CoreText
import SwiftUI

/// Fonts are registered only for this process, never installed on the Mac.
public enum PaceTypography {
    static var rowNativeFont: NSFont { .systemFont(ofSize: 14, weight: .medium) }
    static let rowFont = Font(rowNativeFont)

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
    // Every main-view vertical stack and outer margin uses this single source.
    static let verticalGap: CGFloat = 4
    static let rowHeight: CGFloat = ceil(PaceTypography.rowNativeFont.capHeight)
    static let barHeight: CGFloat = 10
    static let comparisonHeight = 2 * barHeight + verticalGap
    static let minimumWindowHeight: CGFloat = 120
    static let horizontalPadding: CGFloat = 13
    static let barInset: CGFloat = 3
    static let columnGap: CGFloat = 10
    static let labelWidth: CGFloat = 118
    static let countdownWidth: CGFloat = 170
    static let dateWidth: CGFloat = 132
    static let durationNumberWidth: CGFloat = 18
    // The system-medium "m" needs 13 points, including layout rounding.
    static let durationUnitWidth: CGFloat = 13
    static let durationPartWidth = durationNumberWidth + durationUnitWidth
    static let durationGap: CGFloat = 6
    static let countdownOffset: CGFloat = 14
}

/// Measure single-line text by its glyphs, so font leading does not add hidden
/// spacing to the shared vertical rhythm. Baselines and full glyphs are retained.
struct PaceInkText: View {
    let value: String
    var font: NSFont = PaceTypography.rowNativeFont
    var tracking: CGFloat = 0
    var monospacedDigits = false

    var body: some View {
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: value, attributes: [.font: font, .kern: tracking]
        ))
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        PaceTextInkLayout(top: ceil(ink.maxY), bottom: floor(ink.minY)) {
            Text(value).font(monospacedDigits ? Font(font).monospacedDigit() : Font(font))
                .tracking(tracking).lineLimit(1)
        }
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

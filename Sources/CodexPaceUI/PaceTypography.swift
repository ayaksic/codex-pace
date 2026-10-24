import AppKit
import CoreText
import SwiftUI

/// Fonts are registered only for this process, never installed on the Mac.
public enum PaceTypography {
    static let rowFont = Font.system(size: 14, weight: .medium)

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
    static let sectionGap: CGFloat = 14
    static let rowGap: CGFloat = 6
    static let rowHeight: CGFloat = 24
    static let horizontalPadding: CGFloat = 13
    static let barInset: CGFloat = 3
    static let columnGap: CGFloat = 10
    static let labelWidth: CGFloat = 118
    static let countdownWidth: CGFloat = 170
    static let dateWidth: CGFloat = 132
    static let durationNumberWidth: CGFloat = 18
    static let durationUnitWidth: CGFloat = 10.8
    static let durationPartWidth = durationNumberWidth + durationUnitWidth
    static let durationGap: CGFloat = 6
    static let countdownOffset: CGFloat = 14
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

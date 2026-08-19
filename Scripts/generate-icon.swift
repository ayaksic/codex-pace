#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift OUTPUT.icns\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("CodexPace-\(UUID().uuidString).iconset", isDirectory: true)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }

func render(size: Int, filename: String) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(size) * 0.055
    let tile = canvas.insetBy(dx: inset, dy: inset)
    let background = NSBezierPath(
        roundedRect: tile,
        xRadius: CGFloat(size) * 0.22,
        yRadius: CGFloat(size) * 0.22
    )
    NSColor(calibratedRed: 0.09, green: 0.40, blue: 0.93, alpha: 1).setFill()
    background.fill()

    let pointSize = CGFloat(size) * 0.54
    let baseConfiguration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    let colorConfiguration = NSImage.SymbolConfiguration(hierarchicalColor: .white)
    let configuration = baseConfiguration.applying(colorConfiguration)
    let symbol = (
        NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)
    )?.withSymbolConfiguration(configuration)

    if let symbol {
        let side = CGFloat(size) * 0.64
        let rect = NSRect(
            x: (CGFloat(size) - side) / 2,
            y: (CGFloat(size) - side) / 2,
            width: side,
            height: side
        )
        symbol.draw(in: rect)
    }

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: iconsetURL.appendingPathComponent(filename))
}

for baseSize in [16, 32, 128, 256, 512] {
    try render(size: baseSize, filename: "icon_\(baseSize)x\(baseSize).png")
    try render(size: baseSize * 2, filename: "icon_\(baseSize)x\(baseSize)@2x.png")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", outputURL.path, iconsetURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }

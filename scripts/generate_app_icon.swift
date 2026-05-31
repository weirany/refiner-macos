#!/usr/bin/env swift

import AppKit
import Foundation

enum IconGenerationError: Error, CustomStringConvertible {
    case missingBitmapContext
    case missingPNGRepresentation
    case iconutilFailed(Int32)

    var description: String {
        switch self {
        case .missingBitmapContext:
            "Could not create a bitmap graphics context."
        case .missingPNGRepresentation:
            "Could not create a PNG representation."
        case let .iconutilFailed(status):
            "iconutil failed with status \(status)."
        }
    }
}

struct IconColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            CGFloat((hex >> 16) & 0xff) / 255,
            CGFloat((hex >> 8) & 0xff) / 255,
            CGFloat(hex & 0xff) / 255,
            alpha
        )
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

enum AppIconRenderer {
    private static let canvasSize: CGFloat = 1024

    static func pngData(pixelSize: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw IconGenerationError.missingBitmapContext
        }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw IconGenerationError.missingBitmapContext
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(
            x: CGFloat(pixelSize) / canvasSize,
            y: CGFloat(pixelSize) / canvasSize
        )
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw IconGenerationError.missingPNGRepresentation
        }

        return data
    }

    private static func drawIcon() {
        drawBase()
        drawSelectionBar()
        drawLettermark()
        drawSparkle()
    }

    private static func drawBase() {
        let rect = NSRect(x: 72, y: 72, width: 880, height: 880)
        let path = NSBezierPath(roundedRect: rect, xRadius: 196, yRadius: 196)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        shadow.shadowBlurRadius = 42
        shadow.shadowOffset = NSSize(width: 0, height: -20)
        shadow.set()
        IconColor(hex: 0x121A2A).nsColor.setFill()
        path.fill()

        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        let gradient = NSGradient(colors: [
            IconColor(hex: 0x18223B).nsColor,
            IconColor(hex: 0x0B6F72).nsColor,
            IconColor(hex: 0x26B39A).nsColor,
        ])
        gradient?.draw(in: rect, angle: -38)

        IconColor(hex: 0xF4D35E, alpha: 0.17).nsColor.setFill()
        NSBezierPath(
            ovalIn: NSRect(x: 505, y: 508, width: 460, height: 350)
        ).fill()

        IconColor(hex: 0x07111E, alpha: 0.24).nsColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884),
            xRadius: 196,
            yRadius: 196
        ).fill()

        IconColor(hex: 0xFFFFFF, alpha: 0.16).nsColor.setStroke()
        let rim = NSBezierPath(roundedRect: rect.insetBy(dx: 9, dy: 9), xRadius: 187, yRadius: 187)
        rim.lineWidth = 9
        rim.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawSelectionBar() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.set()

        IconColor(hex: 0xC9FFF2, alpha: 0.92).nsColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 206, y: 304, width: 612, height: 132),
            xRadius: 66,
            yRadius: 66
        ).fill()

        IconColor(hex: 0x2FD7B4, alpha: 0.96).nsColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 250, y: 352, width: 306, height: 28),
            xRadius: 14,
            yRadius: 14
        ).fill()
    }

    private static func drawLettermark() {
        let font = NSFont(name: "AvenirNext-Heavy", size: 610)
            ?? NSFont.systemFont(ofSize: 610, weight: .black)
        let letter = "R" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: IconColor(hex: 0xF7FBFF).nsColor,
        ]
        let bounds = letter.boundingRect(
            with: NSSize(width: canvasSize, height: canvasSize),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        let origin = NSPoint(
            x: (canvasSize - bounds.width) / 2 - bounds.minX + 4,
            y: (canvasSize - bounds.height) / 2 - bounds.minY - 54
        )

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
        shadow.shadowBlurRadius = 20
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        letter.draw(at: origin, withAttributes: attributes)

        IconColor(hex: 0xB6FFF1, alpha: 0.40).nsColor.setStroke()
        let underline = NSBezierPath(
            roundedRect: NSRect(x: 292, y: 238, width: 440, height: 28),
            xRadius: 14,
            yRadius: 14
        )
        underline.lineWidth = 1
        underline.fill()
    }

    private static func drawSparkle() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -7)
        shadow.set()

        IconColor(hex: 0xFFE36E).nsColor.setFill()
        starPath(center: NSPoint(x: 758, y: 718), outerRadius: 86, innerRadius: 27).fill()

        IconColor(hex: 0xFFF7BD).nsColor.setFill()
        starPath(center: NSPoint(x: 844, y: 626), outerRadius: 34, innerRadius: 11).fill()
    }

    private static func starPath(
        center: NSPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat
    ) -> NSBezierPath {
        let path = NSBezierPath()
        for index in 0..<8 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 4
            let point = NSPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        path.close()
        return path
    }
}

enum MenuBarIconRenderer {
    private static let pixelSize = 36

    static func pngData() throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw IconGenerationError.missingBitmapContext
        }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw IconGenerationError.missingBitmapContext
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw IconGenerationError.missingPNGRepresentation
        }

        return data
    }

    private static func drawIcon() {
        NSColor.black.setFill()

        let font = NSFont(name: "AvenirNext-Heavy", size: 26)
            ?? NSFont.systemFont(ofSize: 26, weight: .black)
        let letter = "R" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]
        let bounds = letter.boundingRect(
            with: NSSize(width: pixelSize, height: pixelSize),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        let origin = NSPoint(x: 6 - bounds.minX, y: 4 - bounds.minY)
        letter.draw(at: origin, withAttributes: attributes)

        NSBezierPath(
            roundedRect: NSRect(x: 4, y: 6, width: 22, height: 4),
            xRadius: 2,
            yRadius: 2
        ).fill()

        starPath(center: NSPoint(x: 27, y: 26), outerRadius: 5.2, innerRadius: 1.7).fill()
        starPath(center: NSPoint(x: 32, y: 19), outerRadius: 2.7, innerRadius: 0.9).fill()
    }

    private static func starPath(
        center: NSPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat
    ) -> NSBezierPath {
        let path = NSBezierPath()
        for index in 0..<8 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 4
            let point = NSPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        path.close()
        return path
    }
}

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let iconsetURL = rootURL.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)
let outputURL = rootURL.appendingPathComponent("App/AppIcon.icns")
let menuBarIconURL = rootURL.appendingPathComponent("Sources/Refiner/Resources/MenuBarIconTemplate@2x.png")
let sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for (fileName, pixelSize) in sizes {
    let data = try AppIconRenderer.pngData(pixelSize: pixelSize)
    try data.write(to: iconsetURL.appendingPathComponent(fileName))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c",
    "icns",
    "-o",
    outputURL.path,
    iconsetURL.path,
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw IconGenerationError.iconutilFailed(process.terminationStatus)
}

try fileManager.createDirectory(
    at: menuBarIconURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try MenuBarIconRenderer.pngData().write(to: menuBarIconURL)

print("Generated \(outputURL.path)")
print("Generated \(menuBarIconURL.path)")

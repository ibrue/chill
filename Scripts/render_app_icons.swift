import AppKit
import CoreGraphics
import Foundation

struct IconSpec {
    let points: Int
    let scale: Int
    let filename: String

    var pixels: Int { points * scale }
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Chill/Assets.xcassets/AppIcon.appiconset")

let specs = [
    IconSpec(points: 16, scale: 1, filename: "icon_16x16.png"),
    IconSpec(points: 16, scale: 2, filename: "icon_16x16@2x.png"),
    IconSpec(points: 32, scale: 1, filename: "icon_32x32.png"),
    IconSpec(points: 32, scale: 2, filename: "icon_32x32@2x.png"),
    IconSpec(points: 128, scale: 1, filename: "icon_128x128.png"),
    IconSpec(points: 128, scale: 2, filename: "icon_128x128@2x.png"),
    IconSpec(points: 256, scale: 1, filename: "icon_256x256.png"),
    IconSpec(points: 256, scale: 2, filename: "icon_256x256@2x.png"),
    IconSpec(points: 512, scale: 1, filename: "icon_512x512.png"),
    IconSpec(points: 512, scale: 2, filename: "icon_512x512@2x.png"),
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let url = outputDirectory.appendingPathComponent(spec.filename)
    try renderIcon(pixelSize: spec.pixels, to: url)
    print("Rendered \(spec.filename)")
}

private func renderIcon(pixelSize: Int, to url: URL) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw NSError(domain: "IconRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap context"])
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixelSize), y: CGFloat(pixelSize))

    let tileRect = CGRect(x: 0.035, y: 0.035, width: 0.93, height: 0.93)
    let tilePath = CGPath(roundedRect: tileRect, cornerWidth: 0.21, cornerHeight: 0.21, transform: nil)

    context.saveGState()
    context.addPath(tilePath)
    context.clip()

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            NSColor(calibratedRed: 0.30, green: 0.72, blue: 0.94, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.60, green: 0.92, blue: 0.84, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.72, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0.0, 0.55, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0.15, y: 0.95),
        end: CGPoint(x: 0.95, y: 0.05),
        options: []
    )

    drawSoftHighlight(in: context)
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.42).cgColor)
    context.setLineWidth(0.022)
    context.strokePath()
    context.restoreGState()

    drawFan(in: context, small: pixelSize <= 32)

    guard let image = context.makeImage() else {
        throw NSError(domain: "IconRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create CGImage"])
    }

    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconRenderer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    try data.write(to: url, options: .atomic)
}

private func drawSoftHighlight(in context: CGContext) {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let radial = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            NSColor.white.withAlphaComponent(0.42).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawRadialGradient(
        radial,
        startCenter: CGPoint(x: 0.28, y: 0.78),
        startRadius: 0.02,
        endCenter: CGPoint(x: 0.28, y: 0.78),
        endRadius: 0.58,
        options: []
    )
}

private func drawFan(in context: CGContext, small: Bool) {
    context.saveGState()
    context.translateBy(x: 0.5, y: 0.5)

    context.setShadow(offset: CGSize(width: 0, height: -0.018), blur: 0.035, color: NSColor.black.withAlphaComponent(0.22).cgColor)

    for index in 0..<3 {
        context.saveGState()
        context.rotate(by: CGFloat(index) * (2.0 * .pi / 3.0) - .pi / 10.0)

        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 0.045, y: 0.018))
        blade.addCurve(
            to: CGPoint(x: 0.285, y: 0.175),
            control1: CGPoint(x: 0.115, y: 0.12),
            control2: CGPoint(x: 0.215, y: 0.17)
        )
        blade.addCurve(
            to: CGPoint(x: 0.405, y: 0.035),
            control1: CGPoint(x: 0.355, y: 0.18),
            control2: CGPoint(x: 0.415, y: 0.12)
        )
        blade.addCurve(
            to: CGPoint(x: 0.085, y: -0.055),
            control1: CGPoint(x: 0.35, y: -0.03),
            control2: CGPoint(x: 0.20, y: -0.07)
        )
        blade.closeSubpath()

        context.addPath(blade)
        context.setFillColor(NSColor.white.withAlphaComponent(0.88).cgColor)
        context.fillPath()

        if !small {
            context.addPath(blade)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.34).cgColor)
            context.setLineWidth(0.01)
            context.strokePath()
        }

        context.restoreGState()
    }

    context.setShadow(offset: .zero, blur: 0, color: nil)

    context.addEllipse(in: CGRect(x: -0.115, y: -0.115, width: 0.23, height: 0.23))
    context.setFillColor(NSColor(calibratedRed: 0.06, green: 0.30, blue: 0.42, alpha: 1).cgColor)
    context.fillPath()

    context.addEllipse(in: CGRect(x: -0.075, y: -0.075, width: 0.15, height: 0.15))
    context.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    context.fillPath()

    context.addEllipse(in: CGRect(x: -0.035, y: -0.035, width: 0.07, height: 0.07))
    context.setFillColor(NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.78, alpha: 1).cgColor)
    context.fillPath()

    context.restoreGState()
}

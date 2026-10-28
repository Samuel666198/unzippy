#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Draws the 轻解压 app icon at 1024×1024, then the caller generates the iconset.

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("ctx") }

let W = CGFloat(size)
let H = CGFloat(size)

// Canvas is transparent; the squircle is the icon body.
ctx.clear(CGRect(x: 0, y: 0, width: W, height: H))

let bodyInset: CGFloat = 74
let bodyRect = CGRect(x: bodyInset, y: bodyInset, width: W - bodyInset * 2, height: H - bodyInset * 2)
let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 196, cornerHeight: 196, transform: nil)

ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()

// Background gradient
let colors = [
    NSColor(srgbRed: 0.13, green: 0.79, blue: 0.66, alpha: 1).cgColor,
    NSColor(srgbRed: 0.03, green: 0.42, blue: 0.37, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
    end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY),
    options: []
)

// Soft top highlight
let highlightColors = [
    NSColor(white: 1, alpha: 0.22).cgColor,
    NSColor(white: 1, alpha: 0).cgColor,
]
let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: highlightColors as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(
    highlight,
    startCenter: CGPoint(x: W * 0.28, y: H * 0.86),
    startRadius: 0,
    endCenter: CGPoint(x: W * 0.28, y: H * 0.86),
    endRadius: W * 0.7,
    options: []
)

// Faint diagonal texture
ctx.saveGState()
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.035).cgColor)
ctx.setLineWidth(28)
for i in -10...20 {
    let x = CGFloat(i) * 90
    ctx.move(to: CGPoint(x: x, y: bodyRect.minY - 100))
    ctx.addLine(to: CGPoint(x: x + 400, y: bodyRect.maxY + 100))
}
ctx.strokePath()
ctx.restoreGState()

ctx.restoreGState()

let cardColor = NSColor(srgbRed: 0.995, green: 0.99, blue: 0.97, alpha: 1).cgColor

// Card body, slightly rotated
ctx.saveGState()
ctx.translateBy(x: W / 2, y: H / 2)
ctx.rotate(by: -4.5 * .pi / 180)
ctx.translateBy(x: -W / 2, y: -H / 2)

let cardRect = CGRect(x: 292, y: 258, width: 440, height: 508)
let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 58, cornerHeight: 58, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.20).cgColor)
ctx.setFillColor(cardColor)
ctx.addPath(cardPath)
ctx.fillPath()
ctx.restoreGState()

// Content lines on the card (left of zipper)
ctx.setFillColor(NSColor(srgbRed: 0.05, green: 0.45, blue: 0.40, alpha: 0.20).cgColor)
for (index, width) in [116.0, 170.0, 140.0].enumerated() {
    let line = CGRect(x: cardRect.minX + 54, y: cardRect.maxY - 88 - CGFloat(index) * 34, width: width, height: 13)
    ctx.addPath(CGPath(roundedRect: line, cornerWidth: 6, cornerHeight: 6, transform: nil))
}
ctx.fillPath()

// Zipper tracks
let zipperX = cardRect.midX + 98
let zipperTop = cardRect.maxY - 54
let zipperBottom = cardRect.minY + 96
let trackWidth: CGFloat = 30
ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.38, blue: 0.34, alpha: 0.16).cgColor)
ctx.fill(CGRect(x: zipperX - trackWidth - 4, y: zipperBottom, width: trackWidth, height: zipperTop - zipperBottom))
ctx.fill(CGRect(x: zipperX + 4, y: zipperBottom, width: trackWidth, height: zipperTop - zipperBottom))

// Zipper teeth
let teethCount = 9
let spacing = (zipperTop - zipperBottom - 46) / CGFloat(teethCount - 1)
for i in 0..<teethCount {
    let y = zipperTop - 30 - CGFloat(i) * spacing
    let alpha: CGFloat = i % 2 == 0 ? 1.0 : 0.72
    ctx.setFillColor(NSColor(srgbRed: 0.06, green: 0.53, blue: 0.46, alpha: alpha).cgColor)
    let left = CGRect(x: zipperX - 52, y: y - 15, width: 44, height: 30)
    let right = CGRect(x: zipperX + 8, y: y - 15, width: 44, height: 30)
    ctx.addPath(CGPath(roundedRect: left, cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.addPath(CGPath(roundedRect: right, cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.fillPath()
}

// Pull tab
let tabRect = CGRect(x: zipperX - 54, y: cardRect.minY - 46, width: 108, height: 174)
let tabPath = CGMutablePath()
tabPath.addRoundedRect(in: tabRect, cornerWidth: 32, cornerHeight: 32)

let tabColors = [
    NSColor(srgbRed: 1.0, green: 0.76, blue: 0.40, alpha: 1).cgColor,
    NSColor(srgbRed: 0.98, green: 0.60, blue: 0.22, alpha: 1).cgColor,
]
let tabGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: tabColors as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor.black.withAlphaComponent(0.24).cgColor)
ctx.addPath(tabPath)
ctx.clip()
ctx.drawLinearGradient(tabGradient, start: CGPoint(x: tabRect.minX, y: tabRect.maxY), end: CGPoint(x: tabRect.maxX, y: tabRect.minY), options: [])
ctx.restoreGState()

// Hole in the pull tab
let hole = CGRect(x: zipperX - 15, y: tabRect.minY + 38, width: 30, height: 70)
ctx.setFillColor(NSColor(srgbRed: 0.99, green: 0.99, blue: 0.97, alpha: 0.92).cgColor)
ctx.addPath(CGPath(roundedRect: hole, cornerWidth: 15, cornerHeight: 15, transform: nil))
ctx.fillPath()

// Slider block where the teeth meet
let sliderRect = CGRect(x: zipperX - 48, y: zipperBottom - 12, width: 96, height: 58)
ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.36, blue: 0.32, alpha: 1).cgColor)
ctx.addPath(CGPath(roundedRect: sliderRect, cornerWidth: 20, cornerHeight: 20, transform: nil))
ctx.fillPath()
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.35).cgColor)
ctx.setLineWidth(3)
ctx.addPath(CGPath(roundedRect: sliderRect.insetBy(dx: 3, dy: 3), cornerWidth: 17, cornerHeight: 17, transform: nil))
ctx.strokePath()

// Sparkle accents
func sparkle(center: CGPoint, radius: CGFloat, alpha: CGFloat) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y + radius))
    path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + radius * 0.16, y: center.y + radius * 0.16))
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x + radius * 0.16, y: center.y - radius * 0.16))
    path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - radius * 0.16, y: center.y - radius * 0.16))
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x - radius * 0.16, y: center.y + radius * 0.16))
    ctx.setFillColor(NSColor(white: 1, alpha: alpha).cgColor)
    ctx.addPath(path)
    ctx.fillPath()
}
sparkle(center: CGPoint(x: 236, y: 780), radius: 30, alpha: 0.65)
sparkle(center: CGPoint(x: 792, y: 742), radius: 19, alpha: 0.45)
sparkle(center: CGPoint(x: 806, y: 300), radius: 12, alpha: 0.3)

ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"))

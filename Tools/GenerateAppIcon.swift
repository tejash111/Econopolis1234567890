// Offline, procedural project artwork. Run with `swift Tools/GenerateAppIcon.swift` from the repository root.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let navy = CGColor(red: 0.025, green: 0.055, blue: 0.09, alpha: 1)
let teal = CGColor(red: 0.04, green: 0.2, blue: 0.23, alpha: 1)
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [navy, teal] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: .zero, options: [])
let mint = CGColor(red: 0.38, green: 0.96, blue: 0.77, alpha: 1)
let heights: [CGFloat] = [215, 335, 465, 350, 245]
for (i, height) in heights.enumerated() {
    let x = CGFloat(185 + i * 132)
    context.setFillColor(mint.copy(alpha: 0.25 + CGFloat(i) * 0.14)!)
    context.addPath(CGPath(roundedRect: CGRect(x: x, y: 285, width: 98, height: height), cornerWidth: 16, cornerHeight: 16, transform: nil))
    context.fillPath()
    context.setFillColor(mint)
    context.fill(CGRect(x: x + 15, y: 285 + height - 34, width: 68, height: 7))
}
context.setStrokeColor(mint); context.setLineWidth(12); context.setLineCap(.round)
context.move(to: CGPoint(x: 185, y: 240)); context.addLine(to: CGPoint(x: 840, y: 240)); context.strokePath()
guard let image = context.makeImage() else { fatalError("Cannot render icon") }
let url = URL(fileURLWithPath: "EconopolisApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination))

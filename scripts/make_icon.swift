import AppKit
import CoreGraphics

let size: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("no context")
}
// Work in top-down coordinates: y=0 is the top of the image.
func T(_ y: CGFloat) -> CGFloat { size - y }
func rectTD(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> CGRect {
    CGRect(x: x, y: T(y + h), width: w, height: h)
}

// Background: warm cream
ctx.setFillColor(CGColor(red: 0.96, green: 0.93, blue: 0.87, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Glass body (trapezoid, wider at top). Top-down coords.
let glassTop: CGFloat = 220
let glassBottom: CGFloat = 830
let topHalf: CGFloat = 260
let bottomHalf: CGFloat = 200
let cx = size / 2
let glass = CGMutablePath()
glass.move(to: CGPoint(x: cx - topHalf, y: T(glassTop)))
glass.addLine(to: CGPoint(x: cx + topHalf, y: T(glassTop)))
glass.addLine(to: CGPoint(x: cx + bottomHalf, y: T(glassBottom)))
glass.addQuadCurve(to: CGPoint(x: cx - bottomHalf, y: T(glassBottom)),
                   control: CGPoint(x: cx, y: T(glassBottom + 40)))
glass.closeSubpath()

// Glass fill
ctx.saveGState()
ctx.addPath(glass)
ctx.setFillColor(CGColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// Contents, clipped to glass
ctx.saveGState()
ctx.addPath(glass)
ctx.clip()
// Dark stout: from surface (y=334) down to bottom
ctx.setFillColor(CGColor(red: 0.13, green: 0.07, blue: 0.04, alpha: 1))
ctx.fill(rectTD(x: 0, y: 334, w: size, h: glassBottom + 60 - 334))
// Foam head above the surface
ctx.setFillColor(CGColor(red: 0.95, green: 0.88, blue: 0.72, alpha: 1))
ctx.fill(rectTD(x: 0, y: 274, w: size, h: 60))
// Target band etched on the glass
ctx.setFillColor(CGColor(gray: 1, alpha: 0.85))
ctx.fill(rectTD(x: 0, y: 490, w: size, h: 10))
ctx.fill(rectTD(x: 0, y: 540, w: size, h: 10))
// Vertical highlight
ctx.setFillColor(CGColor(gray: 1, alpha: 0.10))
ctx.fill(rectTD(x: cx - topHalf + 50, y: glassTop, w: 60, h: glassBottom - glassTop))
ctx.restoreGState()

// Glass outline
ctx.saveGState()
ctx.addPath(glass)
ctx.setStrokeColor(CGColor(red: 0.35, green: 0.25, blue: 0.18, alpha: 1))
ctx.setLineWidth(16)
ctx.strokePath()
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")

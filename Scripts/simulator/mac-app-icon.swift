// Renders a Mac app's icon as full-bleed square iOS icon PNGs: the icon's
// squircle is found by its alpha, cropped just inside, and scaled to each size.
// usage: macicon <App.app> <outdir> <prefix>
import AppKit

let args = CommandLine.arguments
let app = args[1], out = args[2], prefix = args[3]
let icon = NSWorkspace.shared.icon(forFile: app)
let side = 1024
func render(dark: Bool) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let draw = { icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1) }
    NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance(draw)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
func opaqueBounds(_ rep: NSBitmapImageRep) -> NSRect {
    // The squircle's straight edges: the middle row and column, where alpha is high.
    func alpha(_ x: Int, _ y: Int) -> CGFloat { rep.colorAt(x: x, y: y)!.alphaComponent }
    let mid = side / 2
    var l = 0; while l < mid && alpha(l, mid) < 0.9 { l += 1 }
    var r = side - 1; while r > mid && alpha(r, mid) < 0.9 { r -= 1 }
    var t = 0; while t < mid && alpha(mid, t) < 0.9 { t += 1 }
    var b = side - 1; while b > mid && alpha(mid, b) < 0.9 { b -= 1 }
    return NSRect(x: l, y: t, width: r - l + 1, height: b - t + 1)
}
func write(_ rep: NSBitmapImageRep, crop: NSRect, size: Int, to path: String) {
    let cg = rep.cgImage!.cropping(to: crop)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
    let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}
let light = render(dark: false)
var box = opaqueBounds(light)
// Square it on the larger side and come in 1.2% so iOS's own mask cuts inside the Mac shape.
let s = max(box.width, box.height), inset = (s * 0.012).rounded()
box = NSRect(x: box.midX - s / 2 + inset, y: box.midY - s / 2 + inset, width: s - 2 * inset, height: s - 2 * inset).integral
let sizes: [(String, Int)] = [("60x60@2x", 120), ("60x60@3x", 180), ("76x76@2x~ipad", 152), ("83.5x83.5@2x~ipad", 167), ("1024x1024", 1024)]
for (name, px) in sizes { write(light, crop: box, size: px, to: "\(out)/\(prefix)\(name).png") }
print("\(app): squircle \(Int(box.width))px at \(Int(box.minX)),\(Int(box.minY))")

//
//  WallpaperFile.swift
//  LiveContainerSwiftUI
//

import CoreImage
import ImageIO
import UIKit

/// The wallpaper's files: the halo zContainer comes with, in its bundle, and
/// in Application Support a JPEG made from the chosen photo, turned upright and made no bigger than the largest screens need,
/// so it loads quickly and doesn't hold a 48 megapixel photo in memory.
enum WallpaperFile {
    /// The longest side, in pixels, a wallpaper is made at on iPhone: a little
    /// more than the largest iPhone screen. iPads never go below it either.
    private static let maximumPixelSize = 3000

    /// The longest side of the largest iPad screen, in pixels: the 13 inch
    /// iPad Pro's 2752. The photo's short side has to reach it, since an
    /// iPad turns and a photo then fills the screen along its short side.
    private static let padScreenLongSide = 2752

    /// The longest side, in pixels, a wallpaper is made at on iPad, however
    /// long and narrow the photo, so a panorama doesn't take up a lot of memory.
    private static let padMaximumPixelSize = 4096

    /// The JPEG quality the wallpaper is saved at.
    private static let quality = 0.9

    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Wallpaper.jpg")
    }

    /// The saved wallpaper, decoded for drawing, or nil when there's none.
    static func load() -> UIImage? {
        UIImage(contentsOfFile: url.path(percentEncoded: false))?.preparingForDisplay()
    }

    /// The halo zContainer comes with, decoded for drawing: a square one for
    /// iPads, which fills their screens in both orientations, and a tall one
    /// for iPhones. `Scripts/zc/art/wallpaper` renders both.
    static func loadDefault(isPad: Bool) -> UIImage? {
        UIImage(named: isPad ? "DefaultWallpaperPad" : "DefaultWallpaperPhone")?.preparingForDisplay()
    }

    /// Makes a wallpaper from a photo's data: the picture decoded for
    /// drawing, and the JPEG to save it as.
    static func make(_ data: Data) throws -> (image: UIImage, jpeg: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw WallpaperError.unreadable
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize(for: source)
        ] as CFDictionary
        guard let picture = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw WallpaperError.unreadable
        }
        let image = UIImage(cgImage: picture)
        guard let jpeg = image.jpegData(compressionQuality: quality) else {
            throw WallpaperError.unreadable
        }
        return (image.preparingForDisplay() ?? image, jpeg)
    }

    /// Saves a wallpaper `make` made in place of the last one.
    static func save(_ jpeg: Data) throws {
        try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try jpeg.write(to: url, options: .atomic)
    }

    /// The longest side, in pixels, to make a photo's wallpaper at. On iPhone
    /// it's always `maximumPixelSize`. On iPad it's enough for the photo's
    /// short side to cover the largest iPad's long side, so the wallpaper
    /// stays sharp in both orientations, up to `padMaximumPixelSize`. A photo
    /// smaller than that keeps its own size, since thumbnails never grow.
    private static func pixelSize(for source: CGImageSource) -> Int {
        guard
            !SharedModel.isPhone,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else {
            return maximumPixelSize
        }
        let long = max(width, height)
        let short = min(width, height)
        let covering = (padScreenLongSide * long + short - 1) / short
        return min(max(covering, maximumPixelSize), padMaximumPixelSize)
    }

    /// The wallpaper blurred as search blurs the Home Screen, made at a
    /// quarter of its size, which the blur hides, or nil if it can't be made.
    static func blurred(_ image: UIImage) -> UIImage? {
        guard let picture = image.cgImage else {
            return nil
        }
        let small = CIImage(cgImage: picture).transformed(by: CGAffineTransform(scaleX: blurScale, y: blurScale))
        let blurred = small.clampedToExtent().applyingGaussianBlur(sigma: blurRadius).cropped(to: small.extent)
        guard let output = blurContext.createCGImage(blurred, from: blurred.extent) else {
            return nil
        }
        return UIImage(cgImage: output).preparingForDisplay()
    }

    /// How bright a wallpaper is behind a part of a screen of `screenSize` it
    /// fills, from 0 for black to 1 for white: the part's average color's
    /// luminance. Nil when the part is off the picture.
    static func brightness(of image: UIImage, behind rect: CGRect, onScreenOf screenSize: CGSize) -> Double? {
        guard let picture = image.cgImage, image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        // Where the part falls on the picture, which fills the screen and is
        // centered on it, in the picture's pixels.
        let fill = max(screenSize.width / image.size.width, screenSize.height / image.size.height)
        let left = (screenSize.width - image.size.width * fill) / 2
        let top = (screenSize.height - image.size.height * fill) / 2
        let pixels = Double(picture.width) / image.size.width
        let part = CGRect(
            x: (rect.minX - left) / fill * pixels,
            y: (rect.minY - top) / fill * pixels,
            width: rect.width / fill * pixels,
            height: rect.height / fill * pixels
        ).integral.intersection(CGRect(x: 0, y: 0, width: picture.width, height: picture.height))
        guard !part.isEmpty, let cropped = picture.cropping(to: part) else {
            return nil
        }
        // Drawn into one pixel, which averages it.
        var pixel: [UInt8] = [0, 0, 0, 0]
        let drawn: Bool = pixel.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else {
            return nil
        }
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }

    /// The Core Image context every blurred copy is made in. Making one is
    /// slow, so it's made once and shared.
    private static let blurContext = CIContext()

    /// How much smaller the blurred copy is made.
    private static let blurScale = 0.25

    /// The blur's radius on the smaller copy, in its pixels: about the 24
    /// points search blurs the icons by, on a 3x screen.
    private static let blurRadius = 18.0

    /// Deletes the saved wallpaper.
    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

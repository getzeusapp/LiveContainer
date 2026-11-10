//
//  HomeSystemSettingsIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// The iOS Settings app's own Home Screen icon, light and dark, which the Home
/// Screen shows for zContainer's Settings. IconServices draws it from the
/// Settings app on the device, as it draws the apps' icons, so it is always
/// the system's current icon and zContainer carries none of Apple's artwork.
/// The icons are kept in Caches, for each iOS version, so later launches show
/// them at once. Until they're ready, or where the Settings app can't be
/// read, HomeSettingsArtwork draws a stand-in.
@MainActor
@Observable
final class HomeSystemSettingsIcon {
    static let shared = HomeSystemSettingsIcon()

    private var light: UIImage?
    private var dark: UIImage?
    @ObservationIgnored private var hasStartedLoading = false

    /// The icon in its light or dark version, or nil while it isn't ready.
    func image(isDark: Bool) -> UIImage? {
        isDark ? dark : light
    }

    /// Loads both versions, once: from Caches when they were drawn before,
    /// otherwise drawn by IconServices off the main thread.
    func load() {
        guard !hasStartedLoading else {
            return
        }
        hasStartedLoading = true
        Task.detached(priority: .userInitiated) {
            let light = Self.icon(isDark: false)
            let dark = Self.icon(isDark: true)
            await self.show(light: light, dark: dark)
        }
    }

    private func show(light: UIImage?, dark: UIImage?) {
        self.light = light
        self.dark = dark
    }

    /// One version of the icon, from Caches or newly drawn and saved there.
    nonisolated private static func icon(isDark: Bool) -> UIImage? {
        let saved = cacheURL(isDark: isDark)
        if let image = UIImage(contentsOfFile: saved.path(percentEncoded: false)) {
            return image
        }
        guard let app = settingsAppURL,
              FileManager.default.isReadableFile(atPath: app.appending(path: "Info.plist").path(percentEncoded: false)) else {
            return nil
        }
        guard let image = UIImage.generateIcon(forBundleURL: app, style: isDark ? .Dark : .Light, hasBorder: false),
              image.cgImage != nil, let png = image.pngData() else {
            return nil
        }
        try? FileManager.default.createDirectory(at: saved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: saved, options: .atomic)
        return image
    }

    /// Where a version of the icon is kept. iOS updates can redesign the
    /// icon, so each version of iOS gets its own.
    nonisolated private static func cacheURL(isDark: Bool) -> URL {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"
        return URL.cachesDirectory
            .appending(path: "HomeScreen", directoryHint: .isDirectory)
            .appending(path: "SettingsIcon-\(version)-\(isDark ? "dark" : "light").png")
    }

    /// The system's Settings app: in /Applications on a device, and in the
    /// runtime's own /Applications in the Simulator.
    nonisolated private static var settingsAppURL: URL? {
        #if targetEnvironment(simulator)
        guard let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] else {
            return nil
        }
        return URL(fileURLWithPath: root).appending(path: "Applications/Preferences.app", directoryHint: .isDirectory)
        #else
        return URL(fileURLWithPath: "/Applications/Preferences.app", isDirectory: true)
        #endif
    }
}

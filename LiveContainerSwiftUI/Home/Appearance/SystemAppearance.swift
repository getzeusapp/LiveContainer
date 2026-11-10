//
//  SystemAppearance.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Whether zContainer is in Dark Mode: as iOS is, or as chosen in Settings >
/// Appearance, which this gives every one of zContainer's scenes. The Home
/// Screen keeps its own window dark whatever the setting, so the window's
/// appearance can't tell; the scene's still follows the system and the
/// choice, and this follows the scene.
@MainActor
@Observable
final class SystemAppearance {
    /// Whether Dark Mode is on, for zContainer.
    private(set) var isDark = UITraitCollection.current.userInterfaceStyle == .dark

    /// The scene whose appearance this follows. When it disconnects, which
    /// on iPad can happen while zContainer is in the background, the main
    /// window's next scene takes over.
    @ObservationIgnored private weak var followedScene: UIWindowScene?
    @ObservationIgnored private var registration: (any UITraitChangeRegistration)?
    /// The appearance chosen in Settings, which every scene is given.
    @ObservationIgnored private var chosen = AppAppearance.saved

    init() {
        // A scene that connects later, such as a second window on iPad, gets
        // the choice too.
        NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let scene = notification.object as? UIWindowScene else {
                    return
                }
                Self.give(self.chosen, to: scene)
            }
        }
    }

    /// Follows the appearance of the scene zContainer's main window shows in,
    /// from now on, in place of the one it followed before. Calling it again
    /// for the same scene only reads the appearance afresh.
    func follow(_ scene: UIWindowScene) {
        Self.give(chosen, to: scene)
        update(from: scene)
        guard scene !== followedScene else {
            return
        }
        if let registration {
            followedScene?.unregisterForTraitChanges(registration)
        }
        followedScene = scene
        registration = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.update(from: scene)
        }
    }

    /// Gives every one of zContainer's scenes the appearance chosen in Settings.
    func choose(_ appearance: AppAppearance) {
        chosen = appearance
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            Self.give(appearance, to: scene)
        }
        if let followedScene {
            update(from: followedScene)
        }
    }

    /// Makes a scene light or dark as chosen, or lets it follow iOS.
    private static func give(_ appearance: AppAppearance, to scene: UIWindowScene) {
        if let style = appearance.interfaceStyle {
            scene.traitOverrides.userInterfaceStyle = style
        } else if scene.traitOverrides.contains(UITraitUserInterfaceStyle.self) {
            scene.traitOverrides.remove(UITraitUserInterfaceStyle.self)
        }
    }

    /// Reads whether a scene is in Dark Mode, changing `isDark` only when the
    /// answer is new, so the views reading it don't redraw for nothing.
    private func update(from scene: UIWindowScene) {
        let isDark = scene.traitCollection.userInterfaceStyle == .dark
        if isDark != self.isDark {
            self.isDark = isDark
        }
    }
}

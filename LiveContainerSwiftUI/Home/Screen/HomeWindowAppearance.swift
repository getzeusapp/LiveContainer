//
//  HomeWindowAppearance.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// Keeps the window the Home Screen shows in dark while `isDark`, which makes
/// the status bar's text white over the wallpaper, as on iOS, and what opens
/// from the Home Screen dark. It darkens the window, where SwiftUI's
/// preferredColorScheme would darken the whole scene: the scene keeps
/// following the system's appearance, which SystemAppearance reads for the
/// icons, the wallpaper and the dock's glass.
struct HomeWindowAppearance: UIViewRepresentable {
    /// Whether the window is dark, rather than following the system.
    let isDark: Bool

    func makeUIView(context: Context) -> WindowView {
        let view = WindowView()
        view.isUserInteractionEnabled = false
        view.isDark = isDark
        return view
    }

    func updateUIView(_ view: WindowView, context: Context) {
        view.isDark = isDark
    }

    /// An empty view that sets the appearance of the window it's in.
    final class WindowView: UIView {
        var isDark = false {
            didSet {
                if isDark != oldValue {
                    apply()
                }
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else {
                return
            }
            let style: UIUserInterfaceStyle = isDark ? .dark : .unspecified
            guard window.overrideUserInterfaceStyle != style else {
                return
            }
            window.overrideUserInterfaceStyle = style
            window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

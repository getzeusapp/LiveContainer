//
//  SettingsPage.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A page of Settings, which a row of its list opens. On iPad the list is
/// Settings' sidebar, and the page picked there shows beside it, as in the
/// iPad's Settings app.
enum SettingsPage: Hashable {
    /// Settings > Zeus, behind the card at the top.
    case zeus
    /// Settings > Zeus again, opened from the row under the card that says
    /// what is wrong. It is a page of its own so that, in the iPad's sidebar,
    /// only the row that was tapped is highlighted, as in the Settings app.
    case attention
    /// Settings > General.
    case general
    /// Settings > Appearance.
    case appearance
    /// Settings > Wallpaper.
    case wallpaper
    /// Settings > Apps, which holds each app's settings.
    case apps
    /// Settings > Advanced.
    case advanced
    /// An app's settings, by its Home Screen key, which search opens straight
    /// from the app's name, as the Settings app's search does.
    case app(String)

    /// The page that shows for this one: the attention row's is Zeus's.
    /// The iPad's detail column is rebuilt only when this changes, so moving
    /// the selection from the attention row to the card keeps the page.
    var shownPage: SettingsPage {
        self == .attention ? .zeus : self
    }
}

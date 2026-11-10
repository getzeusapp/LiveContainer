//
//  HomeFolderMiniIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One of the small icons on a folder's icon: an app's icon or Settings',
/// in the shape of an app icon, or an empty space where the folder has no
/// more icons.
struct HomeFolderMiniIcon: View {
    /// The icon, or nil for an empty space.
    let item: HomeItem?
    /// Its width and height.
    let size: Double
    /// Whether an app's icon shows in its dark version.
    let darkModeIcon: Bool

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let cornerRadius = size * HomeDesign.iconCornerFraction
        Group {
            switch item {
            case .app(let key)?:
                if let app = model.apps[key] {
                    HomeAppIconImage(app: app, isDark: darkModeIcon)
                        .clipShape(.rect(cornerRadius: cornerRadius))
                } else {
                    Color.clear
                }
            case .settings?:
                HomeSettingsArtwork(size: size, cornerRadius: cornerRadius)
            case .folder?, .widget?, nil:
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
}

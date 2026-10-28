//
//  HomeIconMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The menu a long press on an icon opens, as on the iOS Home Screen. An app's
/// menu has its own actions first, then Face ID, Edit Home Screen and Remove
/// App; a folder's has Rename and Edit Home Screen; Settings' has only Edit
/// Home Screen. In edit mode the menu is empty, so a long press picks the
/// icon up instead. A drag out of the menu starts edit mode while the menu is
/// still closing, and changing a closing menu crashes UIKit, so the menus keep
/// their actions until that drag ends.
struct HomeIconMenu: View {
    /// The icon the menu belongs to.
    let item: HomeItem
    /// The app behind the icon, or nil for Settings.
    let app: LCAppModel?

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        if !model.isEditing || model.isMenuDragging {
            switch item {
            case .app:
                if let app {
                    HomeAppMenu(app: app, showsEditHomeScreen: true)
                }
            case .folder(let id):
                Button("zc.home.renameFolder".loc, systemImage: "pencil") {
                    model.renameFolderFromMenu(id)
                }
                Button("zc.home.editHomeScreen".loc, systemImage: .homeScreenSymbol, action: model.beginEditingAfterMenu)
            case .settings:
                Button("zc.home.editHomeScreen".loc, systemImage: .homeScreenSymbol, action: model.beginEditingAfterMenu)
            }
        }
    }
}

//
//  HomeCustomizeSheet.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Customize, from edit mode's Edit menu, as iOS's sheet that picks how the
/// Home Screen looks: here the app theme, Light, Dark or Automatic, which the
/// icons and widgets follow, as in Settings > Appearance.
struct HomeCustomizeSheet: View {
    @AppStorage(AppAppearance.storageKey, store: LCUtils.appGroupUserDefault) private var appearance = AppAppearance.automatic
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AppThemePicker(appearance: $appearance)
                }
            }
            .navigationTitle("zc.home.customize".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("lc.common.done".loc, systemImage: "checkmark") {
                        model.isCustomizing = false
                    }
                }
            }
        }
        .tint(AppAccent.color)
        .presentationDetents([.height(420)])
    }
}

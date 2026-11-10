//
//  HomeAppMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's long-press menu: the container to run it in when it has several,
/// Open with JIT, whether it always opens with JIT, whether it opens in a
/// multitasking window (on iPhone: Open in Split Screen, and whether it
/// opens with multitasking), Open in New Container and its settings; then Add to
/// Home Screen, which puts it on the iPhone's own Home Screen; then locking
/// it behind Face ID, Edit Home Screen, and Remove App.
struct HomeAppMenu: View {
    @ObservedObject var app: LCAppModel
    /// Whether Edit Home Screen shows, which it doesn't for apps found in search.
    let showsEditHomeScreen: Bool
    /// Whether it's the menu of a recent app in the iPad's dock, whose
    /// settings zoom out of its place there.
    var isRecent = false

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        if app.uiContainers.count > 1 {
            Picker(selection: $app.uiSelectedContainer) {
                ForEach(app.uiContainers, id: \.self) { container in
                    Text(verbatim: container.name)
                        .tag(Optional(container))
                }
            } label: {
                Label("lc.common.container".loc, systemImage: "shippingbox")
            }
            .pickerStyle(.menu)
        }

        Section {
            Button("zc.home.openWithJIT".loc, systemImage: "bolt", action: openWithJIT)
            // A 32-bit app always opens with JIT.
            Toggle("zc.home.alwaysOpenWithJIT".loc, systemImage: "bolt.badge.automatic", isOn: $app.uiIsJITNeeded)
                .disabled(app.uiIs32bit)
            if SharedModel.isPhone {
                // An iPhone has no windows: an app with multitasking fills the
                // screen, or a half of the split screen.
                Button("zc.home.openInSplitScreen".loc, systemImage: "rectangle.split.1x2", action: openInSplitScreen)
                    .disabled(!model.canOpenInSplitScreen(app))
                Toggle("zc.home.openWithMultitasking".loc, systemImage: "square.on.square", isOn: $app.opensInWindow)
            } else {
                Toggle("zc.home.openInWindow".loc, systemImage: "macwindow", isOn: $app.opensInWindow)
            }
            Button("zc.home.openInNewContainer".loc, systemImage: "plus.square.on.square", action: openInNewContainer)
            Button("zc.home.appSettings".loc, systemImage: "gearshape", action: showSettings)
        }

        Section {
            Button("lc.appBanner.addToHomeScreen".loc, systemImage: "plus.app", action: addToHomeScreen)
        }

        Section {
            HomeLockMenu(app: app)
            if showsEditHomeScreen {
                Button("zc.home.editHomeScreen".loc, systemImage: .homeScreenSymbol, action: model.beginEditingAfterMenu)
            }
            if !app.uiIsShared {
                Button("zc.home.removeApp".loc, systemImage: "minus.circle", role: .destructive, action: requestRemoval)
            }
        }
    }

    private func openWithJIT() {
        model.openWithJIT(app)
    }

    private func addToHomeScreen() {
        model.addToHomeScreen(app, style: darkModeIcon ? .Dark : .Light)
    }

    private func openInSplitScreen() {
        model.openInSplitScreen(app)
    }

    private func openInNewContainer() {
        model.openInNewContainer(app)
    }

    private func showSettings() {
        model.showSettings(for: app, fromRecent: isRecent)
    }

    private func requestRemoval() {
        model.requestRemoval(of: app)
    }
}

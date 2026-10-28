//
//  HomeAppMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's long-press menu: the container to run it in when it has several,
/// Open with JIT, whether it always opens with JIT, whether it opens in a
/// multitasking window, Open in New Container and its settings; then Add to
/// Home Screen, which puts it on the iPhone's own Home Screen; then locking
/// it behind Face ID, Edit Home Screen, and Remove App.
struct HomeAppMenu: View {
    @ObservedObject var app: LCAppModel
    /// Whether Edit Home Screen shows, which it doesn't for apps found in search.
    let showsEditHomeScreen: Bool

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
            // Multitasking windows need iOS 16.
            if #available(iOS 16.0, *) {
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

    private func openInNewContainer() {
        model.openInNewContainer(app)
    }

    private func showSettings() {
        model.showSettings(for: app)
    }

    private func requestRemoval() {
        model.requestRemoval(of: app)
    }
}

//
//  HomePresentations.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What opens over the Home Screen: Settings and an app's settings, the
/// question before an app is deleted, the install link question, Files, and
/// Add to Home Screen's sheet, from an app's long-press menu.
/// The Home Screen view applies it once, through `homePresentations(zoomNamespace:)`.
struct HomePresentations: ViewModifier {
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model

    func body(content: Content) -> some View {
        @Bindable var model = model

        content
            .modifier(HomeScreenPresentation(model: model, zoomNamespace: zoomNamespace))
            .alert(
                model.removalTitle,
                isPresented: Binding<Bool>.isPresented(for: $model.pendingRemoval),
                presenting: model.pendingRemoval
            ) { app in
                HomeRemovalActions(app: app)
            } message: { app in
                if !app.uiContainers.isEmpty {
                    Text("zc.home.deleteKeepDataMessage".loc)
                }
            }
            .alert(
                "zc.widget.removeTitle %@".localizeWithFormat(model.pendingWidgetRemoval.map(model.title(of:)) ?? ""),
                isPresented: Binding<Bool>.isPresented(for: $model.pendingWidgetRemoval),
                presenting: model.pendingWidgetRemoval
            ) { _ in
                Button("zc.widget.removeConfirm".loc, role: .destructive, action: model.removePendingWidget)
                Button("lc.common.cancel".loc, role: .cancel) { }
            } message: { _ in
                Text("zc.widget.removeMessage".loc)
            }
            .modifier(HomeWidgetGalleryPresentation(isPresented: $model.isAddingWidget))
            .sheet(isPresented: $model.isCustomizing) {
                HomeCustomizeSheet()
            }
            .sheet(isPresented: $model.isAddingMultitaskApp) {
                HomeAddAppSheet()
            }
            .alert("lc.appList.installFromUrl".loc, isPresented: $model.isEnteringInstallURL) {
                TextField(text: $model.installURL, prompt: Text(verbatim: "https://")) {
                    Text("lc.appList.installFromUrl".loc)
                }
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button("lc.common.install".loc, action: model.installFromEnteredURL)
                Button("lc.common.cancel".loc, role: .cancel) { }
            }
            .betterFileImporter(
                isPresented: $model.isChoosingIPA,
                types: [.ipa, .tipa],
                multiple: false,
                callback: model.installPickedFiles,
                onDismiss: model.filePickerDidClose
            )
            .appShortcutPresenter($model.shortcutRequest)
    }
}

extension View {
    /// Lets the Home Screen open its screens and questions over this view.
    /// Apply it once, to the Home Screen view.
    func homePresentations(zoomNamespace: Namespace.ID) -> some View {
        modifier(HomePresentations(zoomNamespace: zoomNamespace))
    }
}

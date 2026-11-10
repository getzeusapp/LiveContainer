//
//  AppsSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Apps, like the Apps page of the Settings app: every app inside
/// zContainer by name, under its first letter, each opening its settings,
/// with a search field and, on iOS 26 and later, the index of letters along
/// the edge. Hidden Apps comes last and opens after Face ID, Touch ID or the
/// passcode, as on iOS.
struct AppsSettingsView: View {
    @EnvironmentObject private var sharedModel: SharedModel

    @State private var searchText = ""
    @State private var isShowingHiddenApps = false
    @State private var errorMessage: String?

    var body: some View {
        let sections = AppsLetterSection.sections(of: sharedModel.apps, matching: searchText)

        List {
            if sharedModel.apps.isEmpty {
                Section {
                    ContentUnavailableView(
                        "zc.settings.apps.empty".loc,
                        systemImage: "square.grid.2x2",
                        description: Text("zc.settings.apps.emptyDetail".loc)
                    )
                }
                .listRowBackground(Color.clear)
            }

            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.apps, id: \.self) { app in
                        NavigationLink {
                            SettingsAppPage(app: app)
                        } label: {
                            SettingsAppRow(app: app)
                        }
                    }
                }
                .modifier(AppsSectionIndexLabel(label: section.title))
            }

            if searchText.isEmpty {
                Section {
                    Button(action: showHiddenApps) {
                        SettingsDisclosureLabel(title: "lc.appList.hiddenApps".loc)
                    }
                }
            }
        }
        .modifier(AppsSectionIndexVisibility())
        .overlay {
            if !searchText.isEmpty && sections.isEmpty {
                ContentUnavailableView.search
            }
        }
        .navigationTitle("lc.tabView.apps".loc)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "zc.settings.apps.search".loc)
        .settingsBottomSearch()
        .navigationDestination(isPresented: $isShowingHiddenApps) {
            HiddenAppsSettingsView()
        }
        .alert(
            "lc.common.error".loc,
            isPresented: Binding<Bool>.isPresented(for: $errorMessage),
            presenting: errorMessage
        ) { _ in
            Button("lc.common.ok".loc) { }
        } message: { message in
            Text(message)
        }
    }

    /// Opens Hidden Apps once Face ID, Touch ID or the passcode passes, which
    /// shows the hidden apps until zContainer quits.
    private func showHiddenApps() {
        Task {
            do {
                isShowingHiddenApps = try await LCUtils.authenticateUser()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

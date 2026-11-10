//
//  SettingsRootList.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The list Settings opens on, holding SettingsRootSections' rows. On iPhone
/// each row pushes its page. On iPad the list is the sidebar of Settings'
/// split view and picks the page that shows beside it, as in the iPad's
/// Settings app.
struct SettingsRootList: View {
    /// On iPad, the page picked in the sidebar. Nil on iPhone, where the list
    /// has nothing to pick and each row pushes its page.
    var selection: Binding<SettingsPage?>?

    @Environment(ZeusConnection.self) private var connection
    /// What's typed into the search field, whose results take the list's
    /// place while there's any.
    @State private var query = ""

    var body: some View {
        Group {
            // Only the iPad passes a selection, and the device never changes,
            // so the list never switches between the two.
            if let selection {
                List(selection: selection) {
                    content
                }
            } else {
                List {
                    content
                }
            }
        }
        // At the bottom on iPhone, as in the Settings app, and always at the
        // top of the sidebar on iPad.
        .searchable(text: $query, placement: SharedModel.isPhone ? .automatic : .navigationBarDrawer(displayMode: .always))
        .settingsBottomSearch()
        // Zeus may have brought a certificate, or the launch check found a
        // problem, since Settings last looked.
        .onAppear(perform: connection.reload)
    }

    @ViewBuilder
    private var content: some View {
        if query.isEmpty {
            SettingsRootSections()
        } else {
            SettingsSearchResults(query: query)
        }
    }
}

extension View {
    /// Puts the search field of a page of Settings along the bottom on
    /// iPhone, as the Settings app has its search and Apps' on iOS 26 and
    /// later, with zContainer's Home button beside it, in place of the bar
    /// under the screen, which would push the field up. iPad keeps search at
    /// the top.
    func settingsBottomSearch() -> some View {
        modifier(SettingsBottomSearch())
    }
}

/// Puts a page's search field and the Home button in its bottom bar, and
/// tells the screen to leave out its own Home button bar while the page is
/// the one showing.
private struct SettingsBottomSearch: ViewModifier {
    @Environment(HomeScreenModel.self) private var model
    /// Whether the page is the one showing, rather than one pushed over it.
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .modifier(SettingsBottomSearchField(goHome: model.goHome))
            .onAppear {
                isShowing = true
            }
            .onDisappear {
                isShowing = false
            }
            .preference(key: SettingsBottomBarHomeButton.self, value: isShowing && SettingsBottomSearchField.isUsed)
    }
}

/// Puts a page's search field along the bottom on iPhone, with zContainer's
/// Home button beside it.
private struct SettingsBottomSearchField: ViewModifier {
    /// What the Home button does.
    let goHome: () -> Void

    /// Whether the search field and the Home button share the bottom bar.
    static var isUsed: Bool {
        if #available(iOS 26.0, *) {
            SharedModel.isPhone
        } else {
            false
        }
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), Self.isUsed {
            content.toolbar {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button(action: goHome) {
                        HomeButtonGlyph(color: .primary)
                            .scaleEffect(SettingsDesign.toolbarHomeGlyphScale)
                            .frame(width: SettingsDesign.toolbarHomeGlyphSize, height: SettingsDesign.toolbarHomeGlyphSize)
                    }
                    .accessibilityLabel("zc.home.homeButton".loc)
                    .accessibilityHint("zc.home.homeButtonHint".loc)
                }
            }
        } else {
            content
        }
    }
}

/// Whether a page of Settings is showing with the Home button in its bottom
/// bar, where the screen leaves out its own Home button bar.
struct SettingsBottomBarHomeButton: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

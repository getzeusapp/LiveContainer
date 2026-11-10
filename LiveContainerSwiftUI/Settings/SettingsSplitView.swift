//
//  SettingsSplitView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings on iPad, laid out like the iPad's Settings app: Settings' list in
/// a sidebar, and beside it the page picked there, in a navigation stack of
/// its own so the page's links push inside it. A window too narrow for both,
/// like Slide Over, collapses it into one stack that opens on the list, as
/// Settings on iPhone does.
///
/// While both columns show, the Home button sits at the bottom of the sidebar
/// instead of in a bar across the whole screen, while the iPad's own Home
/// button is below the screen. Turned so it's beside the screen, the bar runs
/// down that side instead. A collapsed window keeps the bar, so the button
/// stays in reach on every page.
struct SettingsSplitView: View {
    @Environment(HomeScreenModel.self) private var model
    @Environment(ZeusConnection.self) private var connection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.homeButtonEdge) private var homeButtonEdge

    /// The page picked in the sidebar. Nil while a collapsed window shows the
    /// list alone. With room for both columns it is never nil, so the detail
    /// column is never empty.
    @State private var page: SettingsPage?
    /// Both columns show, as in the Settings app, which has no button to hide
    /// its sidebar either.
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    /// The column a collapsed window shows. It starts on the list, so a
    /// narrow window opens on Settings' rows rather than on a page.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            // A plain sidebar, as the iPad's Settings app has, with the page
            // picked lit up in it.
            SettingsRootList(selection: $page)
                .listStyle(.sidebar)
                .navigationTitle("lc.tabView.settings".loc)
                .modifier(SidebarTitleHidden())
                .navigationSplitViewColumnWidth(min: Self.sidebarMinimumWidth, ideal: Self.sidebarWidth, max: Self.sidebarMaximumWidth)
                .toolbar(removing: .sidebarToggle)
                .settingsSidebarHomeButton(isShown: Self.placesHomeButtonInSidebar(horizontalSizeClass, edge: homeButtonEdge), action: model.goHome)
        } detail: {
            if let page {
                NavigationStack {
                    SettingsPageView(page: page.shownPage)
                }
                // Another page starts afresh, without what was pushed on the
                // last one.
                .id(page.shownPage)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: horizontalSizeClass, initial: true, settleSelection)
        .onChange(of: hasAttentionPage, settleSelection)
        .onChange(of: page, pageChanged)
    }

    /// Whether the Home button sits at the bottom of the sidebar instead of in
    /// a bar across the screen: on iPad, while the window is wide enough for
    /// the sidebar to show beside a page, and the iPad's Home button, which
    /// zContainer's goes beside, is below the screen (`edge`).
    /// HomePresentedScreenView leaves its bar out then.
    static func placesHomeButtonInSidebar(_ sizeClass: UserInterfaceSizeClass?, edge: HomeButtonEdge) -> Bool {
        !SharedModel.isPhone && sizeClass == .regular && edge == .bottom
    }

    /// Whether the row under the Zeus card opens a page, which it does unless
    /// zContainer was never set up and the row opens onboarding.
    private var hasAttentionPage: Bool {
        guard let attention = connection.attention else {
            return false
        }
        return attention != .notSetUp
    }

    /// Keeps a row picked while both columns show: General when nothing is,
    /// as in the Settings app, and the Zeus card once the row under it goes
    /// away, as fixing the problem on that page makes it. The page showing
    /// stays the same then.
    private func settleSelection() {
        guard horizontalSizeClass == .regular else {
            return
        }
        if page == nil {
            page = .general
        } else if page == .attention && !hasAttentionPage {
            page = .zeus
        }
    }

    /// While both columns show, has a collapsing window show the page picked,
    /// not the list, so narrowing the window doesn't take the page away. In a
    /// collapsed window the split view keeps this up to date itself.
    private func pageChanged() {
        guard horizontalSizeClass == .regular else {
            return
        }
        compactColumn = page == nil ? .sidebar : .detail
    }

    /// The sidebar's width, about the iPad Settings app's, and the narrowest
    /// and widest the split view may make it.
    private static let sidebarWidth = 375.0
    private static let sidebarMinimumWidth = 320.0
    private static let sidebarMaximumWidth = 420.0
}

/// Leaves the sidebar without a title over its search field, as the iPad's
/// Settings app has it. The title still names the window.
private struct SidebarTitleHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}

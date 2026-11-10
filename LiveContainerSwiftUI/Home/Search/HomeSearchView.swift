//
//  HomeSearchView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Search over the Home Screen, laid out as iOS 26.5's Spotlight. Before
/// anything is typed it suggests the apps opened most recently, one row of
/// them until Show More, and offers the hidden apps behind Face ID. Once
/// something is typed it shows the best match as the Top Hit and the other
/// apps found in rows. A tap beside the results closes search, as on iOS.
/// VoiceOver stays in search while it's open.
///
/// On iPhone search fills the screen over the blurred Home Screen, its
/// sections from the top of the safe area and the field at the bottom, above
/// the keyboard. With the keyboard down, the Home button under the field
/// closes search too.
///
/// On iPad, as iPadOS's Spotlight, search is a panel of glass near the top of
/// the screen, over the Home Screen as it is: the field along its top, and
/// the sections under it, the panel growing with them down the screen. The
/// Home button shows in the row above the dock whenever no on-screen keyboard
/// covers the bottom, as with a hardware keyboard.
struct HomeSearchView: View {
    @Environment(HomeScreenModel.self) private var model
    @Environment(\.homeButtonEdge) private var homeButtonEdge
    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var isFieldFocused: Bool
    /// Whether the Home button shows: on iPhone under the field whenever the
    /// field doesn't have the keyboard; on iPad, whenever no on-screen
    /// keyboard is up. As search opens it waits a moment for the keyboard,
    /// so it doesn't flash, and shows if the keyboard never came.
    @State private var showsHomeButton = false
    /// Whether an on-screen keyboard is up: the field widens over it, as
    /// Spotlight's does, and on iPad the Home button goes.
    @State private var isKeyboardUp = false
    /// How tall the sections in iPad's panel are, for the panel to fit them.
    @State private var padSectionsHeight = 0.0

    var body: some View {
        Group {
            if SharedModel.isPhone {
                phoneSearch
            } else {
                padSearch
            }
        }
        .environment(\.homeSearchLayout, layout)
        // On an iPad turned so its Home button is beside the screen, or above
        // it, the Home button stands against that edge instead.
        .overlay(alignment: edgeAlignment) {
            if showsHomeButton && homeButtonEdge != .bottom {
                HomeButton(action: model.goHome)
                    .padding(HomeDesign.homeButtonBarPadding)
                    .transition(.opacity)
            }
        }
        .animation(HomeDesign.modeChange, value: showsHomeButton)
        .animation(HomeDesign.modeChange, value: isKeyboardUp)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        // A pull down shows search before it opens; the field takes the
        // keyboard once it does.
        .onChange(of: model.isSearching, initial: true) {
            if model.isSearching {
                focusField()
            }
        }
        .task(id: model.isSearching) {
            guard model.isSearching else {
                return
            }
            await showHomeButtonIfUnfocused()
        }
        .onChange(of: isFieldFocused, fieldFocusChanged)
        .onReceive(OnScreenKeyboard.changes, perform: keyboardChanged)
    }

    private var layout: HomeSearchLayout {
        SharedModel.isPhone ? .phone : .pad
    }

    /// Where things go on this screen, for the icons: on iPad at Spotlight's
    /// size rather than the Home Screen's.
    private var metrics: HomeMetrics {
        let metrics = model.padMetrics ?? model.metrics ?? .reference
        return SharedModel.isPhone ? metrics : metrics.withIconSize(HomeDesign.padSearchIconSize)
    }

    /// iPhone's search: the sections scrolling over the whole screen, and
    /// the field under them.
    private var phoneSearch: some View {
        GeometryReader { proxy in
            ScrollView {
                sections(columns: HomeDesign.searchPanelColumns)
                    // Inside the scroll view, so it scrolls from the margins too.
                    .padding(.horizontal, HomeDesign.searchMargin)
                    // A tap beside the results closes search, as on iOS.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    .background(closesOnTap)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .homeSearchScrollEdges()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                fieldBar
            }
        }
    }

    /// iPad's search: the panel, 80 points from the top of the screen, as
    /// tall as its sections down to 80 points from the bottom, or above an
    /// on-screen keyboard. A tap beside it closes search.
    private var padSearch: some View {
        GeometryReader { proxy in
            let panelWidth = min(HomeDesign.padSearchPanelWidth, proxy.size.width - 2 * HomeDesign.padSearchPanelSideMargin)
            let bottom = isKeyboardUp ? HomeDesign.padSearchPanelKeyboardGap : HomeDesign.padSearchPanelBottom
            let sectionsRoom = proxy.size.height - HomeDesign.padSearchPanelTop - bottom - HomeDesign.padSearchFieldHeight
            let columns = layout.columns(across: panelWidth - 2 * HomeDesign.padSearchMargin, iconSize: metrics.iconSize)

            ZStack(alignment: .top) {
                closesOnTap

                padPanel(columns: columns, sectionsHeight: max(min(padSectionsHeight, sectionsRoom), 0))
                    .frame(width: panelWidth)
                    .padding(.top, HomeDesign.padSearchPanelTop)

                // In the row above the dock, as on the Home Screen's other
                // pages, which search leaves in sight.
                if showsHomeButton && homeButtonEdge == .bottom {
                    HomeButton(action: model.goHome)
                        .scaleEffect(metrics.pillButtonScale)
                        .position(metrics.pillCenter)
                        .transition(.opacity)
                }
            }
        }
        // From the top of the screen, as Spotlight places its panel, and
        // down to an on-screen keyboard.
        .ignoresSafeArea(.container)
    }

    /// The glass panel: the field along its top, and under it the sections,
    /// scrolling once they're taller than the room.
    private func padPanel(columns: Int, sectionsHeight: Double) -> some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            HomeSearchField(
                text: $model.searchText,
                isFocused: $isFieldFocused,
                onSubmit: model.openFirstSearchResult,
                onClose: model.closeSearch,
                isPadRow: true
            )
            ScrollView {
                sections(columns: columns)
                    .padding(.horizontal, HomeDesign.padSearchMargin)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                        padSectionsHeight = height
                    }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: sectionsHeight)
        }
        .clipShape(.rect(cornerRadius: HomeDesign.padSearchPanelCornerRadius, style: .continuous))
        .homeGlass(.rounded(HomeDesign.padSearchPanelCornerRadius))
        .background {
            HomeSearchPanelShadow(cornerRadius: HomeDesign.padSearchPanelCornerRadius)
        }
    }

    /// What search shows under the field: suggestions and the hidden apps
    /// before anything is typed, then what was found.
    private func sections(columns: Int) -> some View {
        let query = model.searchQuery
        let results = model.searchResults
        return VStack(spacing: 0) {
            if query.isEmpty {
                HomeSearchSuggestions(apps: results, columns: columns, metrics: metrics)
                HomeHiddenApps(columns: columns, metrics: metrics, isFirst: results.isEmpty)
                    .padding(.top, results.isEmpty ? 0 : layout.panelSectionSpacing)
            } else {
                HomeSearchResults(apps: results, query: query, columns: columns, metrics: metrics)
            }
        }
    }

    /// Space that closes search when tapped, behind the results.
    private var closesOnTap: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture(perform: model.closeSearch)
            .accessibilityHidden(true)
    }

    /// iPhone's field, 3 points above the keyboard or the bottom of the safe
    /// area, 35 points from the sides, or 8 with an on-screen keyboard up,
    /// and the Home button under it while the keyboard is down.
    private var fieldBar: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            HomeSearchField(
                text: $model.searchText,
                isFocused: $isFieldFocused,
                onSubmit: model.openFirstSearchResult,
                onClose: model.closeSearch
            )
            .padding(.horizontal, isKeyboardUp ? HomeDesign.searchFieldKeyboardMargin : HomeDesign.searchFieldMargin)
            .padding(.bottom, HomeDesign.searchFieldBottomGap)

            // The keyboard covers the bottom of the screen while it's up, so
            // the Home button shows under the field once it goes away.
            if showsHomeButton && homeButtonEdge == .bottom {
                HomeButton(action: model.goHome)
                    .padding(.bottom, HomeDesign.homeButtonBarPadding)
                    .transition(.opacity)
            }
        }
    }

    /// Where the Home button stands when it isn't under the field: against
    /// the screen's own left or right edge, whatever the reading direction,
    /// or its top.
    private var edgeAlignment: Alignment {
        let isRightToLeft = layoutDirection == .rightToLeft
        switch homeButtonEdge {
        case .left:
            return isRightToLeft ? .trailing : .leading
        case .right:
            return isRightToLeft ? .leading : .trailing
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    private func focusField() {
        isFieldFocused = true
    }

    /// Shows the Home button when the field still hasn't got the keyboard a
    /// moment after search opened, so it never stays missing. On iPad it goes
    /// by whether an on-screen keyboard came up.
    private func showHomeButtonIfUnfocused() async {
        try? await Task.sleep(for: HomeDesign.searchFocusWait)
        guard !Task.isCancelled else {
            return
        }
        showsHomeButton = SharedModel.isPhone ? !isFieldFocused : !isKeyboardUp
    }

    private func fieldFocusChanged(from wasFocused: Bool, to isFocused: Bool) {
        guard SharedModel.isPhone else {
            return
        }
        showsHomeButton = !isFocused
    }

    /// Follows whether an on-screen keyboard is up, not the shortcuts bar a
    /// hardware keyboard brings, for the field's width. On iPad the Home
    /// button shows whenever none covers the bottom, focused field or not.
    private func keyboardChanged(_ notification: Notification) {
        isKeyboardUp = OnScreenKeyboard.isUp(after: notification)
        guard !SharedModel.isPhone else {
            return
        }
        showsHomeButton = !isKeyboardUp
    }
}

private extension View {
    /// Spotlight's soft edges where its results scroll under the status bar
    /// and the field, from iOS 26.
    @ViewBuilder
    func homeSearchScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

/// The shadow under iPad search's panel, as Spotlight casts it from its
/// panel's outline: black at 50%, 30.5 points soft and 10 points down. It's
/// a layer's shadow, as Spotlight's is, so the panel's glass shows it
/// through, darker over the Home Screen than glass alone.
private struct HomeSearchPanelShadow: UIViewRepresentable {
    let cornerRadius: Double

    func makeUIView(context: Context) -> ShadowView {
        ShadowView()
    }

    func updateUIView(_ view: ShadowView, context: Context) {
        view.cornerRadius = cornerRadius
    }

    final class ShadowView: UIView {
        var cornerRadius = 0.0 {
            didSet {
                setNeedsLayout()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = Float(HomeDesign.padSearchPanelShadowOpacity)
            layer.shadowRadius = HomeDesign.padSearchPanelShadowRadius
            layer.shadowOffset = CGSize(width: 0, height: HomeDesign.padSearchPanelShadowOffset)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        }
    }
}

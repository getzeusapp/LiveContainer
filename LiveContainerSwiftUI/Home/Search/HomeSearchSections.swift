//
//  HomeSearchSections.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A section's title in search, over its panel or rows, as iOS 26.5's
/// Spotlight draws it: 15-point medium text in white at 64%, near the
/// header's bottom, with an action such as Show More at the other end.
/// Further down search the header is taller, with a line along its bottom.
struct HomeSearchSectionHeader: View {
    let title: String
    /// The action at the header's trailing end, if any.
    var actionTitle: String?
    var action: () -> Void = {}
    /// Whether it's search's first section, whose header is shorter and has
    /// no line under it.
    var isFirst = true

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
            }
        }
        .font(.system(size: HomeDesign.searchHeaderFontSize, weight: .medium))
        .foregroundStyle(.white.opacity(HomeDesign.searchHeaderOpacity))
        .lineLimit(1)
        // The text's baseline its inset above the bottom: its descent sits
        // under the baseline.
        .padding(.bottom, (isFirst ? HomeDesign.searchFirstHeaderBaselineInset : HomeDesign.searchHeaderBaselineInset) - HomeDesign.searchHeaderFontSize * HomeDesign.searchHeaderDescentShare)
        .frame(height: isFirst ? HomeDesign.searchFirstHeaderHeight : HomeDesign.searchHeaderHeight, alignment: .bottom)
        .overlay(alignment: .bottom) {
            if !isFirst {
                HomeSearchSeparator()
            }
        }
    }
}

/// The line between search's rows and under its titles.
struct HomeSearchSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(HomeDesign.searchSeparatorOpacity))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Apps as icons with their names on a panel, as Spotlight shows its
/// suggestions and top hit, the icons spread from one side to the other. On
/// iPhone the panel is white at 10%, rounded concentrically with the icons,
/// 16 points around them and 20 under the last row, the rows 16 points
/// apart. On iPad nothing is behind the icons, which have more room around
/// them, as HomeSearchLayout has it.
struct HomeSearchAppPanel: View {
    /// The apps, in rows of `columns`.
    let apps: [LCAppModel]
    /// How many apps a row holds.
    let columns: Int
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics
    /// Whether the first app is the top hit, which the Go key opens, and
    /// shows on a highlight.
    var highlightsFirst = false

    @Environment(\.prefersDarkAppIcons) private var darkModeIcon
    @Environment(\.homeSearchLayout) private var layout

    var body: some View {
        let rows = stride(from: 0, to: apps.count, by: columns).map { start in
            Array(apps[start..<min(start + columns, apps.count)])
        }
        VStack(spacing: layout.panelRowSpacing) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { column in
                        if column > 0 {
                            Spacer(minLength: 0)
                        }
                        if column < rows[rowIndex].count {
                            cell(rows[rowIndex][column], isHighlighted: highlightsFirst && rowIndex == 0 && column == 0)
                        } else {
                            Color.clear
                                .frame(width: metrics.iconSize, height: cellHeight)
                        }
                    }
                }
            }
        }
        .padding([.horizontal, .top], layout.panelPadding)
        .padding(.bottom, layout.panelBottomPadding)
        .background(.white.opacity(layout.showsPanelFill ? HomeDesign.searchPanelOpacity : 0), in: .rect(cornerRadius: metrics.iconCornerRadius + layout.panelPadding, style: .continuous))
    }

    /// An icon's cell: the icon, and room under it for its name, which runs
    /// on wider than the icon and lower.
    private var cellHeight: Double {
        metrics.iconSize + layout.cellLabelRoom
    }

    private func cell(_ app: LCAppModel, isHighlighted: Bool) -> some View {
        HomeSearchResult(app: app, metrics: metrics, darkModeIcon: darkModeIcon)
            .frame(width: metrics.iconSize, height: cellHeight, alignment: .top)
            .background(alignment: .top) {
                if isHighlighted {
                    let outset = HomeDesign.searchTopHitHighlightOutset
                    RoundedRectangle(cornerRadius: metrics.iconCornerRadius + outset, style: .continuous)
                        .fill(.white.opacity(HomeDesign.searchTopHitHighlightOpacity))
                        .frame(width: metrics.iconSize + outset * 2, height: metrics.iconSize + outset * 2)
                        .offset(y: -outset)
                }
            }
    }
}

/// An app found by search, as a row: its icon, and its name beside it in
/// 17-point semibold, 16 points above and below. It opens the app, with its
/// menu on a long press.
struct HomeSearchAppRow: View {
    @ObservedObject var app: LCAppModel
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// Whether a line runs under it, to the next row.
    var showsSeparator = true

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        Button(action: open) {
            HStack(spacing: HomeDesign.searchRowSpacing) {
                HomeIconContent(item: .app(app.homeKey ?? ""), app: app, metrics: metrics, showsLabel: false, darkModeIcon: darkModeIcon)
                Text(app.displayName)
                    .font(.system(size: HomeDesign.searchRowFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, HomeDesign.searchRowPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                HomeSearchSeparator()
                    .padding(.leading, metrics.iconSize + HomeDesign.searchRowSpacing)
            }
        }
        .accessibilityLabel(app.displayName)
        .contentShape(.contextMenuPreview, .rect(cornerRadius: metrics.iconCornerRadius))
        .contextMenu {
            HomeAppMenu(app: app, showsEditHomeScreen: false)
        }
    }

    private func open() {
        model.openSearchResult(app)
    }
}

/// Search before anything is typed: the apps opened most recently, one row
/// of them until Show More brings a second, as Spotlight shows its
/// suggestions.
struct HomeSearchSuggestions: View {
    /// The apps opened most recently, the most recent first.
    let apps: [LCAppModel]
    /// How many apps a row holds.
    let columns: Int
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    @State private var showsMore = false

    var body: some View {
        if !apps.isEmpty {
            VStack(spacing: 0) {
                HomeSearchSectionHeader(
                    title: "zc.home.search.suggestions".loc,
                    actionTitle: apps.count > columns ? (showsMore ? "zc.home.search.showLess" : "zc.home.search.showMore").loc : nil,
                    action: toggleShowsMore
                )
                HomeSearchAppPanel(apps: Array(apps.prefix(showsMore ? columns * 2 : columns)), columns: columns, metrics: metrics)
            }
        }
    }

    private func toggleShowsMore() {
        withAnimation(HomeDesign.modeChange) {
            showsMore.toggle()
        }
    }
}

/// What search found for the text typed, as Spotlight lays it out: the best
/// match as the Top Hit, alone on a panel and highlighted, as the Go key opens
/// it; then the other apps found, in rows under Apps.
struct HomeSearchFoundApps: View {
    /// The apps found, the best match first.
    let apps: [LCAppModel]
    /// How many apps a panel row holds.
    let columns: Int
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    @Environment(\.homeSearchLayout) private var layout

    var body: some View {
        if let topHit = apps.first {
            VStack(spacing: 0) {
                HomeSearchSectionHeader(title: "zc.home.search.topHit".loc)
                HomeSearchAppPanel(apps: [topHit], columns: columns, metrics: metrics, highlightsFirst: true)
                let others = apps.dropFirst()
                if !others.isEmpty {
                    HomeSearchSectionHeader(title: "zc.home.search.apps".loc, isFirst: false)
                        .padding(.top, layout.panelSectionSpacing)
                    ForEach(Array(others.enumerated()), id: \.element) { index, app in
                        HomeSearchAppRow(app: app, metrics: metrics, showsSeparator: index < others.count - 1)
                    }
                }
            }
        }
    }
}

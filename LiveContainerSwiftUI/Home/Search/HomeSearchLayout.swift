//
//  HomeSearchLayout.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Where things go among search's sections, which differ between iPhone's
/// Spotlight, filling the screen, and iPad's, a panel at the top of it.
struct HomeSearchLayout {
    /// How far sections, their titles and lines keep from the sides.
    let margin: Double
    /// Room around the icons on a panel of apps.
    let panelPadding: Double
    /// Room under a panel's last row, for the names that run on lower.
    let panelBottomPadding: Double
    /// Room between a panel's rows.
    let panelRowSpacing: Double
    /// Room under each icon on a panel for its name.
    let cellLabelRoom: Double
    /// Whether a panel of apps has a fill behind its icons.
    let showsPanelFill: Bool
    /// Room between a panel and the header of the section after it, besides
    /// the header's own.
    let panelSectionSpacing: Double

    /// iPhone's: the sections across the screen, their panels filled.
    static let phone = HomeSearchLayout(
        margin: HomeDesign.searchMargin,
        panelPadding: HomeDesign.searchPanelPadding,
        panelBottomPadding: HomeDesign.searchPanelBottomPadding,
        panelRowSpacing: HomeDesign.searchPanelRowSpacing,
        cellLabelRoom: HomeDesign.searchCellLabelRoom,
        showsPanelFill: true,
        panelSectionSpacing: HomeDesign.searchPanelSectionSpacing
    )

    /// iPad's: the sections inside the glass panel, nothing behind the icons.
    static let pad = HomeSearchLayout(
        margin: HomeDesign.padSearchMargin,
        panelPadding: HomeDesign.padSearchPanelPadding,
        panelBottomPadding: HomeDesign.padSearchPanelBottomPadding,
        panelRowSpacing: HomeDesign.padSearchPanelRowSpacing,
        cellLabelRoom: HomeDesign.padSearchCellLabelRoom,
        showsPanelFill: false,
        panelSectionSpacing: HomeDesign.padSearchPanelSectionSpacing
    )

    /// How many apps a panel row holds across the given width of a section:
    /// as many icons as fit at least 16 points apart, from three to six. It
    /// comes to four on iPhone, and six on iPad's 600 point panel, as
    /// Spotlight shows.
    func columns(across sectionWidth: Double, iconSize: Double) -> Int {
        let rowWidth = sectionWidth - 2 * panelPadding
        let fitting = Int((rowWidth + Self.minimumIconSpacing) / (iconSize + Self.minimumIconSpacing))
        return min(max(fitting, 3), 6)
    }

    private static let minimumIconSpacing = 16.0
}

extension EnvironmentValues {
    /// How search lays out its sections here.
    @Entry var homeSearchLayout = HomeSearchLayout.phone
}

//
//  HomeScreenModel+Search.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Search over the Home Screen, which finds apps by name the way Spotlight does.
extension HomeScreenModel {
    /// The most apps search suggests before anything is typed: two rows of
    /// them after Show More, of six on the widest iPad.
    private static let suggestionCount = 12

    /// Opens search, as tapping "Search" or pulling the Home Screen down do.
    func openSearch() {
        guard !isEditing else {
            return
        }
        searchText = ""
        withAnimation(HomeDesign.modeChange) {
            isSearching = true
        }
    }

    /// How much of search shows, from 0 to 1: all of it while it is open,
    /// otherwise as much as a pull down on the pages has brought in.
    var searchPresence: Double {
        isSearching ? 1 : searchPull
    }

    /// How far search has blurred, dimmed and shrunk the Home Screen behind
    /// it and faded its dock: as far as it has come in on iPhone. On iPad
    /// none, as Spotlight's panel leaves the Home Screen as it is.
    var searchBackdropPresence: Double {
        SharedModel.isPhone ? searchPresence : 0
    }

    /// Follows a pull down on the pages, bringing search in as far as it went.
    func searchPullChanged(_ progress: Double) {
        guard !isEditing, !isSearching else {
            return
        }
        searchPull = progress
    }

    /// Ends a pull down on the pages: search opens from where the pull left
    /// it, or goes back away.
    func searchPullEnded(opens: Bool) {
        guard searchPull > 0 else {
            return
        }
        if opens && !isEditing {
            searchText = ""
        }
        withAnimation(HomeDesign.modeChange) {
            if opens && !isEditing {
                isSearching = true
            }
            searchPull = 0
        }
    }

    /// Closes search and forgets what was typed.
    func closeSearch() {
        withAnimation(HomeDesign.modeChange) {
            isSearching = false
        }
        searchText = ""
    }

    /// The text searched for, without spaces at either end.
    var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The apps search shows. Before anything is typed, the apps opened most
    /// recently. Otherwise the apps whose names contain the text, those whose
    /// names start with it first, then by name.
    var searchResults: [LCAppModel] {
        let query = searchQuery
        guard !query.isEmpty else {
            let opened = apps.values.compactMap { app in
                app.appInfo.lastLaunched.map { (app, $0) }
            }
            return opened
                .sorted { $0.1 > $1.1 }
                .prefix(Self.suggestionCount)
                .map(\.0)
        }
        return apps.values
            .filter { $0.displayName.localizedStandardContains(query) }
            .sorted { first, second in
                let firstIsPrefix = first.displayName.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
                let secondIsPrefix = second.displayName.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
                if firstIsPrefix != secondIsPrefix {
                    return firstIsPrefix
                }
                return first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
            }
    }

    /// Opens an app found by search, closing search first.
    func openSearchResult(_ app: LCAppModel) {
        closeSearch()
        launch(app)
    }

    /// Opens the best match, as the keyboard's Go key does.
    func openFirstSearchResult() {
        guard !searchQuery.isEmpty, let first = searchResults.first else {
            return
        }
        openSearchResult(first)
    }
}

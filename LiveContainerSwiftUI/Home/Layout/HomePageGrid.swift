//
//  HomePageGrid.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where a page's icons and widgets sit in its grid, as iOS fills a page:
/// each in turn at the first place it fits, from the top left, an app in one
/// place and a widget in a block of them that starts on an even column. A
/// page without widgets fills its places in order, its nth icon in the nth
/// place, so only pages with widgets lay out differently.
struct HomePageGrid: Equatable, Sendable {
    /// The grid's columns and rows.
    let columns: Int
    let rows: Int
    /// The place each item's top left corner is in, by its position on the
    /// page: row by row, left to right, from 0. Nil for one that doesn't fit.
    let origins: [Int?]
    /// The item covering each place, by its position on the page.
    private let occupants: [Int?]

    init(items: [HomeItem], widgets: [String: HomeWidget], columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        var occupants = [Int?](repeating: nil, count: columns * rows)
        var origins: [Int?] = []
        var cursor = 0
        for (index, item) in items.enumerated() {
            let span = Self.span(of: item, widgets: widgets)
            // An app takes the place after the last one taken, as iOS keeps a
            // page's apps in order around its widgets; a widget the first
            // block that's free.
            let start = span.columns == 1 && span.rows == 1 ? cursor : 0
            var origin: Int?
            for place in start..<(columns * rows) {
                let column = place % columns
                let row = place / columns
                guard column + span.columns <= columns, row + span.rows <= rows else {
                    continue
                }
                if span.columns > 1, column % 2 != 0 {
                    continue
                }
                let isFree = (0..<span.rows).allSatisfy { down in
                    (0..<span.columns).allSatisfy { across in
                        occupants[(row + down) * columns + column + across] == nil
                    }
                }
                if isFree {
                    origin = place
                    break
                }
            }
            origins.append(origin)
            guard let origin else {
                continue
            }
            for down in 0..<span.rows {
                for across in 0..<span.columns {
                    occupants[(origin / columns + down) * columns + origin % columns + across] = index
                }
            }
            if span.columns == 1 && span.rows == 1 {
                cursor = origin + 1
            }
        }
        self.origins = origins
        self.occupants = occupants
    }

    /// The places an item takes, across and down: one for an app, Settings or
    /// a folder, and a widget's block.
    static func span(of item: HomeItem, widgets: [String: HomeWidget]) -> (columns: Int, rows: Int) {
        if case .widget(let id) = item, let widget = widgets[id] {
            return widget.size.span
        }
        return (1, 1)
    }

    /// Whether every item fits.
    var fitsAll: Bool {
        origins.allSatisfy { $0 != nil }
    }

    /// The position on the page of the item covering a place, or nil when it's
    /// free.
    func item(covering place: Int) -> Int? {
        guard place >= 0, place < occupants.count else {
            return nil
        }
        return occupants[place]
    }

    /// Where an app put into the page goes, by its position among the page's
    /// items, so it shows in the first free place: after the last item, as
    /// iOS adds one.
    var nextPosition: Int {
        origins.count
    }
}

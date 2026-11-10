//
//  HomeSlot.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A place for an icon: a position on one of the pages, in the dock, or in a
/// folder. Positions count from 0, left to right and then top to bottom, the
/// way iOS fills a page; a folder's run on from one of its pages to the next.
enum HomeSlot: Hashable, Sendable {
    /// The position `index` on the page `page`.
    case page(Int, index: Int)

    /// The position `index` in the dock.
    case dock(Int)

    /// The position `index` in the folder with the id given.
    case folder(String, index: Int)

    /// The page this slot is on, or nil for the dock.
    var page: Int? {
        if case .page(let page, _) = self {
            page
        } else {
            nil
        }
    }

    /// Whether this slot is in the dock.
    var isInDock: Bool {
        if case .dock = self {
            true
        } else {
            false
        }
    }

    /// The folder this slot is in, or nil for a page or the dock.
    var folder: String? {
        if case .folder(let id, _) = self {
            id
        } else {
            nil
        }
    }

    /// The position right after this one, on the same page, in the dock or
    /// in the same folder.
    var following: HomeSlot {
        switch self {
        case .page(let page, let index):
            .page(page, index: index + 1)
        case .dock(let index):
            .dock(index + 1)
        case .folder(let id, let index):
            .folder(id, index: index + 1)
        }
    }
}

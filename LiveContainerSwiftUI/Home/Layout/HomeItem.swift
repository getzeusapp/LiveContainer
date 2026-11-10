//
//  HomeItem.swift
//  LiveContainerSwiftUI
//

import Foundation

/// One thing on the Home Screen: an app inside zContainer, zContainer's own
/// Settings, a folder of them, or a widget. The layout saves each item as its
/// `id`.
enum HomeItem: Hashable, Identifiable, Sendable {
    /// An installed app, by its key: its bundle ID and the folder it is
    /// installed in, as `bundleId:relativeBundlePath`. The key stays the same
    /// when the app is replaced by a new version or moved between private and
    /// shared storage, so the icon keeps its place.
    case app(String)

    /// zContainer's Settings. It can be moved but not removed.
    case settings

    /// A folder, by the id of its entry in the layout's `folders`.
    case folder(String)

    /// A widget, or a stack of them, by the id of its entry in the layout's
    /// `widgets`. It goes on the pages only, never in the dock or a folder.
    case widget(String)

    /// The text the layout is saved as: `settings`, or `app:` and the app's key.
    var id: String {
        switch self {
        case .app(let key):
            "app:\(key)"
        case .settings:
            "settings"
        case .folder(let id):
            "folder:\(id)"
        case .widget(let id):
            "widget:\(id)"
        }
    }

    /// Whether this is a widget, which stays on the pages.
    var isWidget: Bool {
        if case .widget = self {
            true
        } else {
            false
        }
    }

    /// Whether this is a folder, which can't go into another folder.
    var isFolder: Bool {
        if case .folder = self {
            true
        } else {
            false
        }
    }

    /// Reads an item from the text `id` makes. Returns nil for text that
    /// names no app, Settings, folder or widget.
    init?(id: String) {
        if id == "settings" {
            self = .settings
        } else if id.hasPrefix("app:"), id.count > 4 {
            self = .app(String(id.dropFirst(4)))
        } else if id.hasPrefix("folder:"), id.count > 7 {
            self = .folder(String(id.dropFirst(7)))
        } else if id.hasPrefix("widget:"), id.count > 7 {
            self = .widget(String(id.dropFirst(7)))
        } else {
            return nil
        }
    }
}

extension HomeItem: Codable {
    /// Reads an item saved as its `id`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        guard let item = HomeItem(id: id) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(id) is not a Home Screen item")
        }
        self = item
    }

    /// Saves the item as its `id`, which keeps the saved layout short and readable.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

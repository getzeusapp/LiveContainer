//
//  HomeLayout.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where everything sits: the pages, each holding up to 24 icons in order on
/// an iPhone and 30 on an iPad, or fewer around its widgets, the dock, holding
/// up to 4 on an iPhone and on an iPad as many as iPadOS's holds, the
/// folders, whose icons sit on the pages or in the dock as an app's do, and
/// the widgets, which sit on the pages only. Like iOS, a page has no gaps;
/// icons fill it from the top left, around its widgets, as HomePageGrid
/// places them. HomeLayoutStorage saves it as JSON.
struct HomeLayout: Codable, Equatable, Sendable {
    /// How many icons fit in the dock: 4 on an iPhone, as on iOS, and on an
    /// iPad as many as iPadOS's dock holds there, 20 on most, whose icons
    /// shrink to fit across the screen. It is the device's, not the
    /// window's, so turning or resizing never pushes an icon out of the dock.
    static var dockCapacity: Int {
        SharedModel.isPhone ? 4 : HomePadDock.capacity(showsRecents: HomeDockRecents.isEnabled)
    }

    /// The pages, left to right. There is always at least one, even if empty.
    var pages: [[HomeItem]]
    /// The dock's icons, left to right.
    var dock: [HomeItem]
    /// The folders, by the id their icon carries.
    var folders: [String: HomeFolder]
    /// The widgets, by the id their item carries.
    var widgets: [String: HomeWidget]

    /// A layout with one empty page and Settings in the dock, which is where a
    /// first launch starts before the apps are added.
    init(pages: [[HomeItem]] = [[]], dock: [HomeItem] = [.settings], folders: [String: HomeFolder] = [:], widgets: [String: HomeWidget] = [:]) {
        self.pages = pages.isEmpty ? [[]] : pages
        self.dock = dock
        self.folders = folders
        self.widgets = widgets
    }

    private enum CodingKeys: String, CodingKey {
        case pages
        case dock
        case folders
        case widgets
    }

    /// Reads a saved layout. One saved before folders or widgets came has
    /// none.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pages = try container.decode([[HomeItem]].self, forKey: .pages)
        dock = try container.decode([HomeItem].self, forKey: .dock)
        folders = try container.decodeIfPresent([String: HomeFolder].self, forKey: .folders) ?? [:]
        widgets = try container.decodeIfPresent([String: HomeWidget].self, forKey: .widgets) ?? [:]
    }

    /// The apps in Home Screen order: page by page, then the dock, each
    /// folder's apps where the folder is.
    var appKeysInOrder: [String] {
        (pages.flatMap { $0 } + dock).flatMap(contents).compactMap { item in
            if case .app(let key) = item {
                key
            } else {
                nil
            }
        }
    }

    /// An icon, or the icons in it when it is a folder.
    private func contents(of item: HomeItem) -> [HomeItem] {
        if case .folder(let id) = item {
            folders[id]?.items ?? []
        } else {
            [item]
        }
    }

    /// Whether an icon is in the dock, or in a folder there.
    func isInDock(_ item: HomeItem) -> Bool {
        dock.contains { $0 == item || contents(of: $0).contains(item) }
    }

    /// Where an item is, or nil when it isn't in the layout: on a page, in
    /// the dock, or in a folder.
    func slot(of item: HomeItem) -> HomeSlot? {
        if let index = dock.firstIndex(of: item) {
            return .dock(index)
        }
        for (page, items) in pages.enumerated() {
            if let index = items.firstIndex(of: item) {
                return .page(page, index: index)
            }
        }
        for (id, folder) in folders {
            if let index = folder.items.firstIndex(of: item) {
                return .folder(id, index: index)
            }
        }
        return nil
    }

    /// The slot a new app takes: the first free one on the last page, or the
    /// first on a new page when the last page is full.
    var nextFreeSlot: HomeSlot {
        let lastPage = max(pages.count - 1, 0)
        let items = pages.last ?? []
        if fits(items + [.app("")]) {
            return .page(lastPage, index: items.count)
        }
        return .page(lastPage + 1, index: 0)
    }

    /// The grids a page has to fit, which iOS lays its icons and widgets out
    /// in: an iPhone's 4 by 6; an iPad's 5 by 6 in portrait and 6 by 5 in
    /// landscape, or 4 by 6 and 6 by 4 for a page with widgets, as iPadOS
    /// lays those out.
    static func gridShapes(withWidgets: Bool) -> [(columns: Int, rows: Int)] {
        if SharedModel.isPhone {
            [(4, 6)]
        } else if withWidgets {
            [(4, 6), (6, 4)]
        } else {
            [(5, 6), (6, 5)]
        }
    }

    /// Whether a page's items all fit on it, either way up.
    func fits(_ items: [HomeItem]) -> Bool {
        let withWidgets = items.contains(where: \.isWidget)
        return Self.gridShapes(withWidgets: withWidgets).allSatisfy { shape in
            HomePageGrid(items: items, widgets: widgets, columns: shape.columns, rows: shape.rows).fitsAll
        }
    }

    /// Adds an item where iOS puts a new app: `nextFreeSlot`.
    mutating func append(_ item: HomeItem) {
        insert(item, at: nextFreeSlot)
    }

    /// Takes an item out, wherever it is, a folder included. The page or
    /// folder it leaves can end up empty; `removeEmptyPages()` and
    /// `removeEmptyFolders()` tidy that up. A widget's settings stay, for
    /// it to go back in elsewhere; `removeWidget(_:)` takes it away for good.
    mutating func remove(_ item: HomeItem) {
        dock.removeAll { $0 == item }
        for page in pages.indices {
            pages[page].removeAll { $0 == item }
        }
        for id in Array(folders.keys) {
            folders[id]?.items.removeAll { $0 == item }
        }
    }

    /// Puts an item at a slot, moving the icons after it along. A page that
    /// overflows pushes its last icon onto the start of the next page, adding
    /// one when needed. A position past the end of a page, the dock or a
    /// folder means its end. Returns false, leaving the layout as it was, when
    /// the dock is full or a folder would go into a folder. An item for a
    /// folder that's gone takes the next free slot instead.
    @discardableResult
    mutating func insert(_ item: HomeItem, at slot: HomeSlot) -> Bool {
        switch slot {
        case .dock(let index):
            guard dock.count < Self.dockCapacity, !item.isWidget else {
                return false
            }
            dock.insert(item, at: min(max(index, 0), dock.count))
        case .page(let page, let index):
            let page = max(page, 0)
            while pages.count <= page {
                pages.append([])
            }
            pages[page].insert(item, at: min(max(index, 0), pages[page].count))
            spill(from: page)
        case .folder(let id, let index):
            guard !item.isFolder, !item.isWidget else {
                return false
            }
            guard let count = folders[id]?.items.count else {
                append(item)
                return true
            }
            folders[id]?.items.insert(item, at: min(max(index, 0), count))
        }
        return true
    }

    /// Makes a folder where `target` is, on a page or in the dock, holding
    /// `target` and then `item`, which leaves wherever it was. Returns the
    /// folder's icon, or nil, leaving the layout as it was, when `target` isn't
    /// on a page or in the dock, or either is a folder.
    mutating func makeFolder(of target: HomeItem, adding item: HomeItem, named name: String) -> HomeItem? {
        guard target != item, !target.isFolder, !item.isFolder, !target.isWidget, !item.isWidget else {
            return nil
        }
        var updated = self
        updated.remove(item)
        let id = UUID().uuidString
        let folder = HomeItem.folder(id)
        switch updated.slot(of: target) {
        case .dock(let index)?:
            updated.dock[index] = folder
        case .page(let page, let index)?:
            updated.pages[page][index] = folder
        case .folder?, nil:
            return nil
        }
        updated.folders[id] = HomeFolder(name: name, items: [target, item])
        self = updated
        return folder
    }

    /// Removes the folders with no icons left, and their icons.
    mutating func removeEmptyFolders() {
        let empty = Set(folders.filter { $0.value.items.isEmpty }.keys)
        guard !empty.isEmpty else {
            return
        }
        folders = folders.filter { !empty.contains($0.key) }
        let isEmptyFolder = { (item: HomeItem) -> Bool in
            if case .folder(let id) = item {
                empty.contains(id)
            } else {
                false
            }
        }
        dock.removeAll(where: isEmptyFolder)
        for page in pages.indices {
            pages[page].removeAll(where: isEmptyFolder)
        }
    }

    /// The layout with an item moved to a slot, as it would look if dropped
    /// there. Empty pages stay, so the pages don't shift under the finger while
    /// the item is being dragged.
    func moving(_ item: HomeItem, to slot: HomeSlot) -> HomeLayout {
        var moved = self
        moved.remove(item)
        if !moved.insert(item, at: slot), let origin = self.slot(of: item) {
            // The dock was full: leave the item where it was.
            moved.insert(item, at: origin)
        }
        return moved
    }

    /// The layout with an item moved to a slot and the items that joined it
    /// right after it, in order, as iOS puts down a stack of icons. One that
    /// doesn't fit there, past a full dock or a folder in a folder, goes to
    /// the next free place instead.
    func moving(_ item: HomeItem, with extras: [HomeItem], to slot: HomeSlot) -> HomeLayout {
        guard !extras.isEmpty else {
            return moving(item, to: slot)
        }
        var moved = self
        for extra in extras {
            moved.remove(extra)
        }
        moved = moved.moving(item, to: slot)
        guard var last = moved.slot(of: item) else {
            return moved
        }
        for extra in extras {
            if moved.insert(extra, at: last.following) {
                last = moved.slot(of: extra) ?? last.following
            } else {
                moved.append(extra)
            }
        }
        return moved
    }

    /// Moves each page's overflow on to the next pages, as after a widget
    /// grew.
    mutating func respill() {
        var page = 0
        while page < pages.count {
            spill(from: page)
            page += 1
        }
    }

    /// Moves each page's overflow on to the next pages, as after a widget
    /// grew, except that `kept`, the widget that grew, stays on its page, as
    /// iOS keeps a widget being resized where it is: the items after it go
    /// to the next page first, then those before it, last first, until it
    /// fits.
    mutating func respill(keeping kept: HomeItem) {
        if case .page(let page, _)? = slot(of: kept) {
            while !fits(pages[page]), let index = pages[page].lastIndex(where: { $0 != kept }) {
                let overflow = pages[page].remove(at: index)
                if page + 1 == pages.count {
                    pages.append([])
                }
                pages[page + 1].insert(overflow, at: 0)
            }
        }
        respill()
    }

    /// Takes a widget off the Home Screen for good, its settings too.
    mutating func removeWidget(_ id: String) {
        remove(.widget(id))
        widgets[id] = nil
    }

    /// Puts a widget at the top of a page, as iOS adds one, moving the page's
    /// other items along, and returns its item.
    @discardableResult
    mutating func addWidget(_ widget: HomeWidget, toPage page: Int) -> HomeItem {
        let id = UUID().uuidString
        widgets[id] = widget
        let item = HomeItem.widget(id)
        insert(item, at: .page(max(page, 0), index: 0))
        return item
    }

    /// Removes the pages that have no icons left, keeping at least one page.
    mutating func removeEmptyPages() {
        pages.removeAll { $0.isEmpty }
        if pages.isEmpty {
            pages = [[]]
        }
    }

    /// Brings the layout in line with the apps the Home Screen shows. Apps that
    /// were removed or hidden leave their slot or their folder, apps not yet
    /// placed take the next free slot in the order given, and Settings comes
    /// back if it went missing. Icons listed twice keep their first place.
    /// Folders left with nothing in them go, as do any no icon stands for, and
    /// widgets no item stands for. Widgets stay on the pages.
    mutating func reconcile(withAppKeys keys: [String]) {
        let shown = Set(keys)
        var placed = Set<HomeItem>()
        let savedFolders = folders
        var keptFolders: [String: HomeFolder] = [:]
        func keepsInFolder(_ item: HomeItem) -> Bool {
            switch item {
            case .app(let key):
                shown.contains(key) && placed.insert(item).inserted
            case .settings:
                placed.insert(item).inserted
            case .folder, .widget:
                false
            }
        }
        func keeps(_ item: HomeItem) -> Bool {
            switch item {
            case .app(let key):
                return shown.contains(key) && placed.insert(item).inserted
            case .settings:
                return placed.insert(item).inserted
            case .folder(let id):
                guard keptFolders[id] == nil, var folder = savedFolders[id] else {
                    return false
                }
                folder.items = folder.items.filter(keepsInFolder)
                guard !folder.items.isEmpty else {
                    return false
                }
                keptFolders[id] = folder
                return true
            case .widget(let id):
                return widgets[id] != nil && placed.insert(item).inserted
            }
        }
        dock = dock.filter { !$0.isWidget && keeps($0) }
        for page in pages.indices {
            pages[page] = pages[page].filter(keeps)
        }
        folders = keptFolders
        widgets = widgets.filter { placed.contains(.widget($0.key)) }

        // A layout saved by a different build could hold more than fits.
        while dock.count > Self.dockCapacity {
            let extra = dock.removeLast()
            append(extra)
        }
        var page = 0
        while page < pages.count {
            spill(from: page)
            page += 1
        }

        removeEmptyPages()
        if !placed.contains(.settings) {
            if dock.count < Self.dockCapacity {
                dock.append(.settings)
            } else {
                append(.settings)
            }
        }
        for key in keys where placed.insert(.app(key)).inserted {
            append(.app(key))
        }
    }

    /// Moves a page's overflow onto the following pages: as many of its last
    /// items as it takes for it to fit, a widget's growth pushing out several,
    /// and on from there while the next page overflows in turn.
    private mutating func spill(from page: Int) {
        var page = page
        while page < pages.count, !fits(pages[page]) {
            // A page keeps its first item, which always fits on its own.
            while !fits(pages[page]), pages[page].count > 1 {
                let overflow = pages[page].removeLast()
                if page + 1 == pages.count {
                    pages.append([])
                }
                pages[page + 1].insert(overflow, at: 0)
            }
            page += 1
        }
    }
}

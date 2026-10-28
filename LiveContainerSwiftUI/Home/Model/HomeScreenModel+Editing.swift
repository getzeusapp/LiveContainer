//
//  HomeScreenModel+Editing.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Edit mode: jiggling icons that can be dragged to a new place, into or out
/// of the dock, onto another page by holding them at the side of the screen,
/// into another icon to make or fill a folder, and around in an open folder
/// or out of it, and removed with their minus badge.
extension HomeScreenModel {
    /// Starts edit mode, as Edit Home Screen or a long press on the wallpaper do.
    func beginEditing() {
        guard !isEditing else {
            return
        }
        if isSearching {
            closeSearch()
        }
        withAnimation(HomeDesign.modeChange) {
            isEditing = true
        }
    }

    /// Starts edit mode from Edit Home Screen in an icon's long-press menu,
    /// once the menu has closed, as on iOS. Started at once, the icons would
    /// start to jiggle and get their badges under the menu's shrinking
    /// preview, which would then land on an icon already tilted.
    func beginEditingAfterMenu() {
        Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.menuCloseDuration)
            self?.beginEditing()
        }
    }

    /// Ends edit mode, as Done or a tap on the wallpaper do. An icon still
    /// being dragged drops where it is, and a folder's name being typed is
    /// kept.
    func endEditing() {
        guard isEditing else {
            return
        }
        if drag != nil {
            commitDrop()
        }
        if let openFolderID {
            finishRenaming(openFolderID)
        }
        withAnimation(HomeDesign.modeChange) {
            isEditing = false
        }
    }

    /// Ends edit mode when the wallpaper is tapped.
    func wallpaperTapped() {
        endEditing()
    }

    // MARK: Dragging

    /// Follows the finger moving an icon in edit mode. The first call picks the
    /// icon up; `start` is where the finger first touched it, which keeps the
    /// icon in the same spot under the finger. Over an open folder, its icons
    /// make room for it; elsewhere, see `followOnHomeScreen`.
    func dragChanged(_ item: HomeItem, finger: CGPoint, start: CGPoint) {
        guard isEditing, let metrics else {
            return
        }
        if drag == nil {
            guard let origin = layout.slot(of: item) else {
                return
            }
            let center = iconCenter(of: origin, in: layout, metrics: metrics)
            let grabOffset = CGSize(width: center.x - start.x, height: center.y - start.y)
            liftedIconCenter = center
            withAnimation(HomeDesign.reflow) {
                drag = HomeDrag(item: item, origin: origin, grabOffset: grabOffset, target: origin, preview: layout)
            }
        }
        guard let drag, drag.item == item, !isDropping else {
            return
        }
        if !drag.hasMoved, hypot(finger.x - start.x, finger.y - start.y) > HomeDesign.tapSlop {
            self.drag?.hasMoved = true
        }
        let center = CGPoint(x: finger.x + drag.grabOffset.width, y: finger.y + drag.grabOffset.height)
        liftedIconCenter = center
        if let openFolderID, isFolderShown {
            followInFolder(openFolderID, center: center, metrics: metrics)
        } else {
            followOnHomeScreen(center: center, finger: finger, metrics: metrics)
        }
    }

    /// Follows a dragged icon over the Home Screen. Held over another icon, it
    /// makes ready to go into it after a moment; elsewhere the icons make room
    /// for it once it has hovered over a place for a moment, and holding it
    /// at the side of the screen turns the page. A folder that has just let
    /// it out only makes room, until the icon has moved off it.
    private func followOnHomeScreen(center: CGPoint, finger: CGPoint, metrics: HomeMetrics) {
        let candidate = mergeCandidate(at: center, metrics: metrics)
        if candidate != blockedMerge {
            blockedMerge = nil
        }
        if let candidate, candidate != blockedMerge {
            reflowTask?.cancel()
            reflowTask = nil
            pendingTarget = nil
            scheduleMerge(into: candidate)
        } else {
            cancelMerge()
            scheduleReflow(to: dropSlot(at: center, metrics: metrics))
        }
        updatePageTurn(at: finger, metrics: metrics)
    }

    /// Follows a dragged icon over the open folder: the folder's icons make
    /// room for it. Held outside the folder for a moment once it's out, the
    /// folder goes back into its icon and lets the icon out onto the Home
    /// Screen. Until then, the icon stays in it wherever it's let go.
    private func followInFolder(_ id: String, center: CGPoint, metrics: HomeMetrics) {
        let folderMetrics = HomeFolderMetrics(metrics)
        if folderMetrics.holds(center) {
            folderLeaveTask?.cancel()
            folderLeaveTask = nil
            scheduleReflow(to: folderSlot(id, at: center, folderMetrics: folderMetrics))
        } else if folderLeaveTask == nil, isFolderSettled {
            reflowTask?.cancel()
            reflowTask = nil
            pendingTarget = nil
            folderLeaveTask = Task { [weak self] in
                try? await Task.sleep(for: HomeDesign.folderLeaveDelay)
                guard !Task.isCancelled else {
                    return
                }
                self?.letOutOfFolder()
            }
        }
    }

    /// Sends the open folder back into its icon while the icon dragged out of
    /// it carries on over the Home Screen. The folder's view stays, hidden,
    /// until the drop, as it holds the drag.
    private func letOutOfFolder() {
        folderLeaveTask = nil
        guard let openFolderID, let metrics else {
            return
        }
        finishRenaming(openFolderID)
        isFolderSettled = false
        withAnimation(HomeDesign.folderZoom) {
            isFolderShown = false
        } completion: { [weak self] in
            guard let self, !isFolderShown, self.openFolderID == openFolderID else {
                return
            }
            isFolderLetOut = true
        }
        blockedMerge = .folder(openFolderID)
        followOnHomeScreen(center: liftedIconCenter, finger: liftedIconCenter, metrics: metrics)
    }

    /// Notes the finger letting go of an icon it held in edit mode. A folder
    /// held and let go without moving opens, as a tap on it does, however long
    /// it was held; anything else that was picked up drops.
    func iconReleased(_ item: HomeItem) {
        // Another finger letting go of another icon leaves the drag alone.
        guard drag == nil || drag?.item == item else {
            return
        }
        if case .folder(let id) = item, drag == nil || (drag?.item == item && drag?.hasMoved == false), !isDropping {
            cancelDrag()
            openFolder(id)
            return
        }
        dragEnded()
    }

    /// Drops the dragged icon where it is: it flies to its new place, settling
    /// back to size on the way, and once there the layout is saved without
    /// the folders and pages left empty. Let go over another icon it was
    /// ready to go into, it shrinks into that icon, which becomes a folder
    /// holding both, or takes it in when it is one.
    func dragEnded() {
        stopPageTurn()
        reflowTask?.cancel()
        reflowTask = nil
        pendingTarget = nil
        folderLeaveTask?.cancel()
        folderLeaveTask = nil
        mergeTask?.cancel()
        mergeTask = nil
        pendingMerge = nil
        blockedMerge = nil
        guard var drag, !isDropping, let metrics else {
            return
        }
        if let mergeTarget = drag.mergeTarget, let slot = drag.preview.slot(of: mergeTarget) {
            let destination = iconCenter(of: slot, in: drag.preview, metrics: metrics)
            withAnimation(HomeDesign.drop) {
                liftedIconCenter = destination
                isDropping = true
                isDroppingIntoFolder = true
            } completion: { [weak self] in
                self?.commitMerge()
            }
            return
        }
        let target = dropTarget(at: liftedIconCenter, metrics: metrics)
        if target != drag.target {
            drag.target = target
            drag.preview = layout.moving(drag.item, to: target)
            withAnimation(HomeDesign.reflow) {
                self.drag = drag
            }
        }
        let destination = iconCenter(of: drag.target, in: drag.preview, metrics: metrics)
        withAnimation(HomeDesign.drop) {
            liftedIconCenter = destination
            isDropping = true
        } completion: { [weak self] in
            self?.commitDrop()
        }
    }

    // MARK: Dragging out of the menu

    /// Offers an icon for dragging out of its menu. UIKit asks as the menu
    /// opens, whether or not the icon is then dragged.
    func offerMenuDrag(of item: HomeItem) {
        menuDragItem = item
    }

    /// Follows the finger dragging an icon out of its menu, as on iOS: the
    /// first move starts edit mode and picks the icon up, and from then on it
    /// moves like any icon dragged in edit mode.
    func menuDragMoved(to finger: CGPoint) {
        guard let item = menuDragItem, !isSearching else {
            return
        }
        if !isMenuDragging {
            isMenuDragging = true
            beginEditing()
        }
        guard drag == nil, let metrics, let origin = layout.slot(of: item) else {
            dragChanged(item, finger: finger, start: finger)
            return
        }
        // The finger may be well away from the icon by the time the drag
        // reaches the Home Screen, so the icon comes to the finger.
        dragChanged(item, finger: finger, start: iconCenter(of: origin, in: layout, metrics: metrics))
    }

    /// Drops an icon dragged out of its menu where it is.
    func menuDragEnded() {
        menuDragItem = nil
        guard isMenuDragging else {
            return
        }
        isMenuDragging = false
        dragEnded()
    }

    /// Puts the dragged icon down at once, where it was picked up.
    func cancelDrag() {
        stopPageTurn()
        reflowTask?.cancel()
        reflowTask = nil
        pendingTarget = nil
        folderLeaveTask?.cancel()
        folderLeaveTask = nil
        mergeTask?.cancel()
        mergeTask = nil
        pendingMerge = nil
        blockedMerge = nil
        drag = nil
        isDropping = false
        isDroppingIntoFolder = false
        if !isFolderShown {
            openFolderID = nil
        }
    }

    /// Saves the dragged icon's new place.
    func commitDrop() {
        guard let drag else {
            return
        }
        finishDrop(with: drag.preview)
    }

    /// Puts the dropped icon into the icon it was let go over: at the end of
    /// the folder, or into a new folder made there, holding both, which then
    /// opens, as on iOS.
    private func commitMerge() {
        guard let drag, let target = drag.mergeTarget else {
            commitDrop()
            return
        }
        var merged = layout
        var newFolder: String?
        if case .folder(let id) = target {
            merged.remove(drag.item)
            merged.insert(drag.item, at: .folder(id, index: .max))
        } else if case .folder(let id)? = merged.makeFolder(of: target, adding: drag.item, named: HomeFolder.defaultName) {
            newFolder = id
        } else {
            commitDrop()
            return
        }
        finishDrop(with: merged)
        if let newFolder {
            openFolder(newFolder)
        }
    }

    /// Saves the layout a drop leaves, without the folders and pages it left
    /// empty, staying on the page that shows, and puts the dragged icon down.
    /// A folder the icon was dragged out of, hidden since, closes for good.
    private func finishDrop(with dropped: HomeLayout) {
        var final = dropped
        final.removeEmptyFolders()
        let currentPage = page ?? 0
        let emptyPagesBefore = final.pages.prefix(currentPage).count(where: \.isEmpty)
        final.removeEmptyPages()
        layout = final
        drag = nil
        isDropping = false
        isDroppingIntoFolder = false
        if !isFolderShown {
            openFolderID = nil
        }
        page = min(max(currentPage - emptyPagesBefore, 0), final.pages.count - 1)
        HomeLayoutStorage.save(final)
    }

    /// Where the dragged icon goes if dropped at `center` now: a place in the
    /// open folder while it's over it, back where it was going when it was
    /// let go beside the folder before the folder let it out, or a place on
    /// the Home Screen.
    private func dropTarget(at center: CGPoint, metrics: HomeMetrics) -> HomeSlot {
        guard let openFolderID, isFolderShown else {
            return dropSlot(at: center, metrics: metrics)
        }
        let folderMetrics = HomeFolderMetrics(metrics)
        guard folderMetrics.holds(center) else {
            return drag?.target ?? dropSlot(at: center, metrics: metrics)
        }
        return folderSlot(openFolderID, at: center, folderMetrics: folderMetrics)
    }

    /// The place in an open folder nearest to `center`, on the folder's page
    /// showing. A folder has no gaps, so a place past its last icon means its end.
    private func folderSlot(_ id: String, at center: CGPoint, folderMetrics: HomeFolderMetrics) -> HomeSlot {
        var others = layout
        if let drag {
            others.remove(drag.item)
        }
        let count = others.folders[id]?.items.count ?? 0
        let index = (folderPage ?? 0) * HomeFolder.iconsPerPage + folderMetrics.index(nearest: center)
        return .folder(id, index: min(index, count))
    }

    /// Where an icon held at `center` drops: in the dock when it's over it and
    /// the dock has room, or else on the page showing, beside the icon it's
    /// nearest to, as `slot(beside:)` says. A page has no gaps, so past its
    /// last icon means its end.
    private func dropSlot(at center: CGPoint, metrics: HomeMetrics) -> HomeSlot {
        guard let drag else {
            return .page(page ?? 0, index: 0)
        }
        var others = layout
        others.remove(drag.item)
        // An iPad's dock glass fits its icons, so a dragged icon reaches the
        // dock where the glass would be with it inside, one place wider.
        if metrics.dockContains(center, count: min(others.dock.count + 1, HomeLayout.dockCapacity)) {
            guard others.dock.count < HomeLayout.dockCapacity else {
                return drag.target
            }
            guard let spot = dockIcon(near: center, in: drag.preview, metrics: metrics) else {
                return .dock(0)
            }
            let isBefore = metrics.isDockVertical ? center.y < spot.center.y : center.x < spot.center.x
            return slot(beside: spot, isBefore: isBefore, among: others.dock, at: center, metrics: metrics) { .dock($0) }
        }
        let page = page ?? 0
        let othersOnPage = page < others.pages.count ? others.pages[page] : []
        guard let spot = pageIcon(near: center, in: drag.preview, metrics: metrics) else {
            return .page(page, index: othersOnPage.count)
        }
        return slot(beside: spot, isBefore: center.x < spot.center.x, among: othersOnPage, at: center, metrics: metrics) {
            .page(page, index: $0)
        }
    }

    /// Where the dragged icon goes when held near another, which `others`
    /// lists with the icons around it, the dragged one left out, and `place`
    /// turns a position among them into a slot: before it
    /// when held over its left half, after it over its right half. So the
    /// icon the finger moves toward stays put, and the dragged icon can reach
    /// it to go in. Over the middle of an icon it's already beside, the
    /// dragged icon stays where it is rather than swap sides as the finger
    /// wavers, and over its own place, it stays there.
    private func slot(
        beside spot: HomeIconSpot,
        isBefore: Bool,
        among others: [HomeItem],
        at center: CGPoint,
        metrics: HomeMetrics,
        place: (Int) -> HomeSlot
    ) -> HomeSlot {
        guard let drag, spot.item != drag.item, let index = others.firstIndex(of: spot.item) else {
            return place(min(spot.index, others.count))
        }
        let before = place(index)
        let after = place(index + 1)
        if isOverIcon(centeredAt: spot.center, center, metrics: metrics), drag.target == before || drag.target == after {
            return drag.target
        }
        return isBefore ? before : after
    }

    /// The icon on the page showing nearest to `center`, as `shown` has the
    /// icons, or nil when `center` is past the page's last icon.
    private func pageIcon(near center: CGPoint, in shown: HomeLayout, metrics: HomeMetrics) -> HomeIconSpot? {
        let current = page ?? 0
        guard current < shown.pages.count else {
            return nil
        }
        let index = metrics.gridIndex(nearest: center)
        guard index < shown.pages[current].count else {
            return nil
        }
        return HomeIconSpot(item: shown.pages[current][index], index: index, center: metrics.iconCenter(at: index))
    }

    /// The dock icon nearest to `center`, as `shown` has the icons, or nil
    /// when the dock is empty.
    private func dockIcon(near center: CGPoint, in shown: HomeLayout, metrics: HomeMetrics) -> HomeIconSpot? {
        let count = shown.dock.count
        let spots = shown.dock.indices.map { index in
            HomeIconSpot(item: shown.dock[index], index: index, center: metrics.dockIconCenter(at: index, count: count))
        }
        return spots.min { first, second in
            hypot(first.center.x - center.x, first.center.y - center.y) < hypot(second.center.x - center.x, second.center.y - center.y)
        }
    }

    /// Whether an icon held at `point` is over the icon centered at
    /// `iconCenter` itself, rather than beside it.
    private func isOverIcon(centeredAt iconCenter: CGPoint, _ point: CGPoint, metrics: HomeMetrics) -> Bool {
        let reach = metrics.iconSize * HomeDesign.mergeZone
        return abs(point.x - iconCenter.x) <= reach && abs(point.y - iconCenter.y) <= reach
    }

    /// The center of the icon at a slot, on screen. A slot on a page is taken
    /// to be on the page showing, and one in a folder in the open folder.
    private func iconCenter(of slot: HomeSlot, in layout: HomeLayout, metrics: HomeMetrics) -> CGPoint {
        switch slot {
        case .page(_, let index):
            metrics.iconCenter(at: index)
        case .dock(let index):
            metrics.dockIconCenter(at: index, count: layout.dock.count)
        case .folder(_, let index):
            folderIconCenter(at: index, metrics: metrics)
        }
    }

    /// Makes room for the dragged icon at `target` once it has stayed there a
    /// moment.
    private func scheduleReflow(to target: HomeSlot) {
        guard target != pendingTarget else {
            return
        }
        pendingTarget = target
        reflowTask?.cancel()
        guard target != drag?.target else {
            return
        }
        reflowTask = Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.reflowDelay)
            guard !Task.isCancelled else {
                return
            }
            self?.move(to: target)
        }
    }

    private func move(to target: HomeSlot) {
        guard var drag else {
            return
        }
        drag.target = target
        drag.preview = layout.moving(drag.item, to: target)
        withAnimation(HomeDesign.reflow) {
            self.drag = drag
        }
    }

    // MARK: Making and filling folders

    /// The icon a dragged one is held over closely enough to go into: an app,
    /// Settings or a folder, on the page showing or in the dock, with the
    /// dragged icon over most of it. A folder being dragged goes into
    /// nothing, as folders don't hold folders.
    private func mergeCandidate(at center: CGPoint, metrics: HomeMetrics) -> HomeItem? {
        guard let drag, !drag.item.isFolder else {
            return nil
        }
        let shown = drag.preview
        let spot = if metrics.dockContains(center, count: shown.dock.count) {
            dockIcon(near: center, in: shown, metrics: metrics)
        } else {
            pageIcon(near: center, in: shown, metrics: metrics)
        }
        guard let spot, spot.item != drag.item, isOverIcon(centeredAt: spot.center, center, metrics: metrics) else {
            return nil
        }
        return spot.item
    }

    /// Makes ready to put the dragged icon into `candidate` once it has
    /// hovered there a moment, and opens a folder hovered over a little
    /// longer, so the icon can go in at a place of its choosing.
    private func scheduleMerge(into candidate: HomeItem) {
        guard candidate != pendingMerge else {
            return
        }
        cancelMerge()
        pendingMerge = candidate
        mergeTask = Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.mergeDelay)
            guard !Task.isCancelled, let self, var drag = self.drag else {
                return
            }
            drag.mergeTarget = candidate
            withAnimation(HomeDesign.mergeHighlight) {
                self.drag = drag
            }
            guard case .folder(let id) = candidate else {
                return
            }
            try? await Task.sleep(for: HomeDesign.folderHoverOpenDelay)
            guard !Task.isCancelled else {
                return
            }
            openFolderWithDrag(id)
        }
    }

    /// Stops making ready to put the dragged icon into another.
    private func cancelMerge() {
        pendingMerge = nil
        mergeTask?.cancel()
        mergeTask = nil
        guard var drag, drag.mergeTarget != nil else {
            return
        }
        drag.mergeTarget = nil
        withAnimation(HomeDesign.mergeHighlight) {
            self.drag = drag
        }
    }

    /// Opens the folder a dragged icon has hovered over, so it can be dropped
    /// in at a place of its choosing. The icon goes in at the folder's end
    /// to begin with, so it stays in wherever it's let go while the folder is
    /// open; held outside the folder, the folder lets it out again.
    private func openFolderWithDrag(_ id: String) {
        // An icon dragged out of a folder has its drag in that folder's view,
        // which another folder opening would take away, freezing the drag.
        // It goes into the end of the folder it's held over instead, when let
        // go there.
        guard openFolderID == nil || openFolderID == id else {
            return
        }
        guard var drag, let items = layout.folders[id]?.items else {
            return
        }
        pendingMerge = nil
        mergeTask = nil
        reflowTask?.cancel()
        reflowTask = nil
        stopPageTurn()
        let target = HomeSlot.folder(id, index: items.count(where: { $0 != drag.item }))
        drag.mergeTarget = nil
        drag.target = target
        drag.preview = layout.moving(drag.item, to: target)
        pendingTarget = target
        self.drag = drag
        openFolder(id)
    }

    // MARK: Turning pages while dragging

    /// Starts turning pages while the finger holds the icon at the left or
    /// right side of the screen, and stops when it moves away.
    private func updatePageTurn(at finger: CGPoint, metrics: HomeMetrics) {
        let edge = HomeDesign.pageTurnEdge
        let direction = if metrics.dockContains(finger, count: displayedLayout.dock.count) {
            0
        } else if finger.x < edge {
            -1
        } else if finger.x > metrics.size.width - edge {
            1
        } else {
            0
        }
        guard direction != pageTurnDirection else {
            return
        }
        stopPageTurn()
        pageTurnDirection = direction
        guard direction != 0 else {
            return
        }
        pageTurnTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: HomeDesign.pageTurnDelay)
                guard !Task.isCancelled else {
                    return
                }
                self?.turnPage(by: direction)
            }
        }
    }

    private func stopPageTurn() {
        pageTurnTask?.cancel()
        pageTurnTask = nil
        pageTurnDirection = 0
    }

    /// Turns to the next or previous page with the dragged icon. Past the last
    /// page a new one opens, unless the last page holds only the dragged icon.
    private func turnPage(by direction: Int) {
        guard let drag, let metrics, !isFolderShown else {
            return
        }
        let next = (page ?? 0) + direction
        let pages = drag.preview.pages
        guard next >= 0 else {
            return
        }
        if next >= pages.count {
            let lastPageHasOtherIcons = pages.last?.contains { $0 != drag.item } ?? false
            guard next == pages.count, lastPageHasOtherIcons else {
                return
            }
        }

        var others = layout
        others.remove(drag.item)
        let count = next < others.pages.count ? others.pages[next].count : 0
        let target = HomeSlot.page(next, index: min(metrics.gridIndex(nearest: liftedIconCenter), count))
        reflowTask?.cancel()
        pendingTarget = target
        cancelMerge()
        var turned = drag
        turned.target = target
        turned.preview = layout.moving(drag.item, to: target)
        turned.mergeTarget = nil
        withAnimation(HomeDesign.reflow) {
            self.drag = turned
            page = next
        }
    }

    // MARK: Removing

    /// Asks whether to delete the app behind an icon, as its minus badge does.
    func requestRemoval(of item: HomeItem) {
        guard case .app(let key) = item, let app = apps[key] else {
            return
        }
        pendingRemoval = app
    }

    /// Asks whether to delete an app, as Remove App does.
    func requestRemoval(of app: LCAppModel) {
        pendingRemoval = app
    }

    /// The question asked before an app is deleted.
    var removalTitle: String {
        "zc.home.deleteTitle %@".localizeWithFormat(pendingRemoval?.displayName ?? "")
    }

    /// Deletes an app, and its data unless the person chose to keep it.
    func removeApp(_ app: LCAppModel, deletingData: Bool) {
        Task {
            await coordinator.uninstall(app, deletingData: deletingData)
        }
    }

    /// Whether an icon shows a minus badge in edit mode. Settings and folders
    /// can't be removed, and a shared app has to be made private again in its
    /// settings first, as in LiveContainer.
    func isRemovable(_ item: HomeItem) -> Bool {
        guard case .app(let key) = item, let app = apps[key] else {
            return false
        }
        return !app.uiIsShared
    }
}

//
//  MultitaskDockView.swift
//  LiveContainer
//
//  Created by boa-z on 2025/6/28.
//

import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - App Info Provider
class AppInfoProvider {
    
    static let shared = AppInfoProvider()
    
    private var infoCacheByName = [String: LCAppInfo]()
    private let cacheQueue = DispatchQueue(label: "com.livecontainer.appinfoprovider.cachequeue", attributes: .concurrent)
    
    private init() {}
    
    public func findAppInfo(appName: String, dataUUID: String) -> LCAppInfo? {
        return findAppInfoFromSharedModel(appName: appName, dataUUID: dataUUID) ?? findAppInfo(byName: appName)
    }

    public func findAppInfo(byName appName: String) -> LCAppInfo? {
        if let cachedInfo = cacheQueue.sync(execute: { infoCacheByName[appName] }) {
            return cachedInfo
        }

        var searchPaths: [String] = []
        if let appGroupPath = LCSharedUtils.appGroupPath()?.path {
            searchPaths.append("\(appGroupPath)/LiveContainer/Applications")
        }
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            searchPaths.append("\(docPath)/Applications")
        }

        for appsPath in searchPaths {
            guard let appDirs = try? FileManager.default.contentsOfDirectory(atPath: appsPath) else { continue }
            
            for appDir in appDirs where appDir.hasSuffix(".app") {
                if let appInfo = LCAppInfo(bundlePath: "\(appsPath)/\(appDir)"), appInfo.displayName() == appName {
                    cacheQueue.async(flags: .barrier) { self.infoCacheByName[appName] = appInfo }
                    return appInfo
                }
            }
        }
        return nil
    }

    private func findAppInfoFromSharedModel(appName: String, dataUUID: String) -> LCAppInfo? {
        let allApps = DataManager.shared.model.apps + DataManager.shared.model.hiddenApps
        
        for appModel in allApps {
            if appModel.uiContainers.contains(where: { $0.folderName == dataUUID }) {
                return appModel.appInfo
            }
        }
        
        for appModel in allApps {
            if appModel.appInfo.displayName() == appName {
                return appModel.appInfo
            }
        }
        return nil
    }
}

// MARK: - App Model for Dock
@objc class DockAppModel: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    @objc let appName: String
    @objc let appUUID: String
    let appInfo: LCAppInfo?
    let view: UIView?
    
    @objc init(appName: String, appUUID: String, appInfo: LCAppInfo? = nil, view: UIView?) {
        self.appName = appName
        self.appUUID = appUUID
        self.appInfo = appInfo
        self.view = view
        super.init()
    }
}

// MARK: - MultitaskDockView Manager
@available(iOS 16.0, *)
@objc public class MultitaskDockManager: NSObject, ObservableObject {
    @objc public static let shared = MultitaskDockManager()
    
    @Published var apps: [DockAppModel] = []
    @Published var isVisible: Bool = false
    @Published var isDockHidden: Bool = false
    /// The apps whose windows are out of sight, minimized or in Picture in
    /// Picture, by their container. The dock fades them and drops their dot.
    @Published var hiddenAppUUIDs: Set<String> = []
    @Published var settingsChanged: Bool = false

    /// The view the virtual windows live in, on the main window. Reading it
    /// first puts it there when it isn't yet, since the main window may not
    /// have been known when the manager was made, and brings it back above
    /// the Home Screen.
    @objc public var windowHostingView: VirtualWindowsHostView {
        attachWindowHostingView()
        return hostView
    }

    /// Puts the apps' windows back above the Home Screen, after a screen that
    /// covered it, like Settings, has closed and given the Home Screen back
    /// to the window.
    @objc public func keepWindowsAboveHomeScreen() {
        attachWindowHostingView()
    }

    /// Whether the manager was made, which reading `shared` does.
    private static var isCreated = false

    /// Whether any app's window is on screen, those of apps that ended
    /// included, without making the manager when it hasn't been.
    @objc public static var hasWindows: Bool {
        isCreated && !shared.hostView.subviews.isEmpty
    }
    private let hostView = VirtualWindowsHostView()
    internal var hostingController: UIHostingController<AnyView>?

    public struct Constants {
        // MARK: - Layout & Sizing
        static let defaultDockWidth: CGFloat = 72.0
        static let minAdaptiveDockWidth: CGFloat = 50.0
        static let minAdaptiveIconSize: CGFloat = 10.0
        static let maxIconSize: CGFloat = 100.0
        static let initialDockShowHeight: CGFloat = 120.0
        /// How much of the dock's glass stays on screen while it's tucked into
        /// its side: a tab with a chevron that brings it back.
        static let tuckedTabWidth: CGFloat = 26.0
        /// How tall that tab is: a short handle, not the whole dock.
        static let tuckedTabHeight: CGFloat = 96.0
        /// Room under the last app for its open-window dot.
        static let indicatorSpace: CGFloat = 6.0
        /// How far a finger can move on an icon and still tap it. Further,
        /// it's dragging the dock.
        static let tapSlop: CGFloat = 10.0
        /// How an app's icon comes into the dock and goes out of it, and how
        /// long that takes, after which the dock's frame catches up.
        static let appsAnimation = Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let appsAnimationDuration: TimeInterval = 0.35
        /// How far a drag, or a throw, toward the dock's edge has to go to
        /// tuck it.
        static let tuckDragDistance: CGFloat = 30.0
        static let tuckThrowDistance: CGFloat = 120.0

        // MARK: - Margins & Padding
        static let adaptiveWidthVerticalMargin: CGFloat = 20.0
        static let dockVerticalMargin: CGFloat = 30.0
        static let dockContentSpacing: CGFloat = 8.0
        /// The space inside the dock's glass around its buttons and icons, and
        /// how much it grows for each point the dock is wider than the default.
        static let panelBasePadding: CGFloat = 4.0
        static let panelPaddingPerExtraWidth: CGFloat = 0.2
        
        // MARK: - Ratios & Factors
        static let iconToWidthRatio: CGFloat = 0.75
        static let maxHeightRatioOfAvailableArea: CGFloat = 0.85
        
        // MARK: - Animation & Interaction
        static var hideGestureThreshold: CGFloat {
            get {
                let ans = LCUtils.appGroupUserDefault.double(forKey: "LCDockWidth")
                if ans != 0 {
                    return ans / 5
                } else {
                    return 16
                }
            }
        }
        static let edgeSwipeThreshold: CGFloat = 30.0
        
        static let standardAnimationDuration: TimeInterval = 0.3
        static let longAnimationDuration: TimeInterval = 0.4
        static let shortAnimationDuration1: TimeInterval = 0.15
        static let shortAnimationDuration2: TimeInterval = 0.1
        
        static let standardSpringDamping: CGFloat = 0.8
        static let showHideSpringDamping: CGFloat = 0.7
        static let standardSpringVelocity: CGFloat = 0.3
        static let showHideSpringVelocity: CGFloat = 0.5
        
        static let initialScale: CGFloat = 0.8
        static let bringToFrontScale: CGFloat = 1.02
    }
    
    // Original dock width from user settings (without auto-adjustment)
    private var originalDockWidth: CGFloat {
        let storedValue = LCUtils.appGroupUserDefault.double(forKey: "LCDockWidth")
        return storedValue > 0 ? CGFloat(storedValue) : Constants.defaultDockWidth
    }
    
    // Calculate adaptive dock width (auto-adjust when exceeding safe area)
    public var dockWidth: CGFloat {
        guard !apps.isEmpty else { return originalDockWidth }
        
        let totalVerticalMargin = Constants.adaptiveWidthVerticalMargin * 2
        let availableHeight = self.safeAreaHeight - totalVerticalMargin
        
        let maxSafeHeight = availableHeight * Constants.maxHeightRatioOfAvailableArea
        
        let userWidth = originalDockWidth
        let iconSize = calculateIconSize(for: userWidth)
        let requiredHeight = expandedDockHeight(for: userWidth, iconSize: iconSize)
        
        if requiredHeight > maxSafeHeight && !apps.isEmpty {
            let baseHeight = expandedDockBaseHeight(for: userWidth)
            let availableForIcons = maxSafeHeight - baseHeight
            let maxAllowedIconSize = availableForIcons / CGFloat(apps.count)
            
            let targetIconSize = max(Constants.minAdaptiveIconSize, maxAllowedIconSize)
            
            let targetWidth = targetIconSize / Constants.iconToWidthRatio
            
            return max(Constants.minAdaptiveDockWidth, targetWidth)
        }
        
        return userWidth
    }
    
    // Calculate icon size based on dock width
    private func calculateIconSize(for width: CGFloat) -> CGFloat {
        let iconSize = width * Constants.iconToWidthRatio
        return max(Constants.minAdaptiveIconSize, min(Constants.maxIconSize, iconSize))
    }

    /// Where on its side the dock sits. Like Picture in Picture, it keeps to
    /// the corners and the middle of the sides.
    enum DockAnchor {
        case top, middle, bottom
    }

    /// Where the dock sits on its side. It stays there as it grows or shrinks
    /// with the apps open, and as the screen turns, and the panel grows and
    /// shrinks from that edge.
    @Published private(set) var dockAnchor: DockAnchor = .middle

    /// How far the dock goes past its side when it's tucked away: all of it
    /// but a tab of its glass.
    var dockHiddenOffset: CGFloat {
        let width = dockWidth
        let panelWidth = calculateIconSize(for: width) + panelPadding(for: width) * 2
        let panelInset = max(0, (width - panelWidth) / 2)
        return max(0, width - panelInset - Constants.tuckedTabWidth)
    }

    /// The space inside the dock's glass around its buttons and icons, for a
    /// dock this wide.
    func panelPadding(for width: CGFloat) -> CGFloat {
        max(Constants.panelBasePadding, Constants.panelBasePadding + (width - Constants.defaultDockWidth) * Constants.panelPaddingPerExtraWidth)
    }

    /// How tall the dock is without its icons, as it's drawn: the spacing
    /// between them, and room for the last one's dot, inside its padding.
    private func expandedDockBaseHeight(for width: CGFloat) -> CGFloat {
        let totalSpacingHeight = CGFloat(max(self.apps.count - 1, 0)) * Constants.dockContentSpacing
        return panelPadding(for: width) * 2 + totalSpacingHeight + Constants.indicatorSpace
    }

    private func expandedDockHeight(for width: CGFloat, iconSize: CGFloat) -> CGFloat {
        expandedDockBaseHeight(for: width) + CGFloat(self.apps.count) * iconSize
    }
    


    // Calculate adaptive icon size
    public var adaptiveIconSize: CGFloat {
        return calculateIconSize(for: dockWidth)
    }

    /// The main window, the one showing the Home Screen, which the virtual
    /// windows and the dock go on. On iPad other scenes can be connected too,
    /// so it isn't simply the first one. An iPhone has the one scene, whose
    /// first window it has always used.
    public var keyWindow: UIWindow? {
        if SharedModel.isPhone {
            return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
        }
        return MainWindow.window
    }

    public var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return keyWindow?.safeAreaInsets ?? .zero
        }
        return .zero
    }

    private var safeAreaHeight: CGFloat {
        (keyWindow?.bounds.height ?? 0) - safeAreaInsets.top - safeAreaInsets.bottom
    }
    
    override init() {
        super.init()
        Self.isCreated = true
        attachWindowHostingView()
        setupDockView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: LCUtils.appGroupUserDefault
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    /// Puts the virtual windows' host view on the main window, and waits
    /// while no main window is known.
    ///
    /// It goes on the root view itself, sized to it and above the Home
    /// Screen, and comes back to the front when something covered it.
    /// zContainer's root is its own SwiftUI view rather than a tab bar
    /// controller whose view came first, so the first view there could be one
    /// that scrolls with the Home Screen's pages, and anything the Home Screen
    /// adds later, like its dock, would be drawn over the windows. The host
    /// view passes touches through wherever there's no window, so being on
    /// top costs the Home Screen nothing.
    private func attachWindowHostingView() {
        guard let window = keyWindow, let rootView = window.rootViewController?.view else { return }
        if hostView.superview !== rootView {
            hostView.frame = rootView.bounds
            rootView.addSubview(hostView)
        } else if rootView.subviews.last !== hostView {
            rootView.bringSubviewToFront(hostView)
        }
    }

    @objc private func deviceOrientationDidChange() {
        DispatchQueue.main.async {
            if self.isVisible {
                self.updateDockFrame()
            }
        }
    }
    
    @objc private func userDefaultsDidChange() {
        DispatchQueue.main.async {
            self.settingsChanged.toggle()
            if self.isVisible {
                self.updateDockFrame()
            }
        }
    }
    
    private func setupDockView() {
        DispatchQueue.main.async {
            let dockView = AnyView(MultitaskDockSwiftView()
                .environmentObject(self))
            
            self.hostingController = UIHostingController(rootView: dockView)
            self.hostingController?.view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
            self.hostingController?.view.backgroundColor = .clear
        }
    }

    private func updateDockFrame(animated: Bool = true) {
        guard let hostingController = hostingController, let screenBounds = keyWindow?.bounds else { return }

        let currentDockWidth = self.dockWidth
        
        let dockHeight = calculateTargetDockHeight(forWidth: currentDockWidth)

        let currentFrame = hostingController.view.frame
        let isOnRightSide = (currentFrame.midX > screenBounds.width / 2) || (currentFrame.isEmpty)
        let targetX = calculateTargetX(isDockHidden: self.isDockHidden, 
                                    isOnRightSide: isOnRightSide, 
                                    dockWidth: currentDockWidth, 
                                    screenWidth: screenBounds.width)

        let targetY = targetY(for: dockAnchor, dockHeight: dockHeight, screenHeight: screenBounds.height)
        
        let newFrame = CGRect(x: targetX, y: targetY, width: currentDockWidth, height: dockHeight)
        
        applyNewFrame(newFrame, for: hostingController, animated: animated)
    }

    // MARK: - Frame Calculation Helpers

    private func calculateTargetDockHeight(forWidth width: CGFloat) -> CGFloat {
        if isDockHidden {
            return Constants.tuckedTabHeight
        }
        return expandedDockHeight(for: width, iconSize: calculateIconSize(for: width))
    }

    func calculateTargetX(isDockHidden: Bool, isOnRightSide: Bool, dockWidth: CGFloat, screenWidth: CGFloat) -> CGFloat {

        let safeInsets = self.safeAreaInsets
        var ans : CGFloat
        if isOnRightSide {
            ans = screenWidth - dockWidth
            if self.hostingController?.view.window?.windowScene?.interfaceOrientation == UIInterfaceOrientation.landscapeLeft {
                ans -= safeInsets.right
            }
            
            if isDockHidden {
                ans += self.dockHiddenOffset
            }
        } else {
            ans = 0
            if self.hostingController?.view.window?.windowScene?.interfaceOrientation == UIInterfaceOrientation.landscapeRight {
                ans += safeInsets.left
            }
            if isDockHidden {
                ans -= self.dockHiddenOffset
            }
        }
        
        return ans;

    }

    /// The dock's top for its place on its side: at the top, in the middle or
    /// at the bottom of the safe area, a margin in.
    private func targetY(for anchor: DockAnchor, dockHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let minY = self.safeAreaInsets.top + Constants.dockVerticalMargin
        let maxY = max(minY, screenHeight - self.safeAreaInsets.bottom - dockHeight - Constants.dockVerticalMargin)
        switch anchor {
        case .top:
            return minY
        case .middle:
            return (minY + maxY) / 2
        case .bottom:
            return maxY
        }
    }

    /// Where the dock goes when it's let go, as Picture in Picture goes: to
    /// the side, and the corner or middle of it, nearest where the throw was
    /// headed. Returns its new origin, and keeps to that place from then on.
    func snapOrigin(forProjected projected: CGRect) -> CGPoint {
        guard let screen = keyWindow?.bounds else { return projected.origin }
        let width = dockWidth
        let height = calculateTargetDockHeight(forWidth: width)
        let top = self.safeAreaInsets.top
        let third = (screen.height - self.safeAreaInsets.bottom - top) / 3
        if projected.midY < top + third {
            dockAnchor = .top
        } else if projected.midY > top + third * 2 {
            dockAnchor = .bottom
        } else {
            dockAnchor = .middle
        }
        let x = calculateTargetX(isDockHidden: false, isOnRightSide: projected.midX > screen.width / 2, dockWidth: width, screenWidth: screen.width)
        return CGPoint(x: x, y: targetY(for: dockAnchor, dockHeight: height, screenHeight: screen.height))
    }

    /// Whether a drag tucks the dock into its side, on the left as on the
    /// right: one that's mostly sideways, toward the edge the dock is on,
    /// a little way or flung.
    func dragTucksDock(from frame: CGRect, translation: CGSize, predicted: CGSize) -> Bool {
        guard let screen = keyWindow?.bounds else { return false }
        let isOnRightSide = frame.midX > screen.width / 2
        let isSideways = abs(translation.width) > abs(translation.height) * 1.2
            || abs(predicted.width) > abs(predicted.height) * 1.2
        let toward = isOnRightSide ? translation.width : -translation.width
        let predictedToward = isOnRightSide ? predicted.width : -predicted.width
        return isSideways && (toward > Constants.tuckDragDistance || predictedToward > Constants.tuckThrowDistance)
    }

    /// Whether a drag on the tucked dock pulls it back onto the screen.
    func pullBringsDockOut(from frame: CGRect, translation: CGSize) -> Bool {
        guard let screen = keyWindow?.bounds else { return false }
        let inward = frame.midX > screen.width / 2 ? -translation.width : translation.width
        return inward > Constants.hideGestureThreshold
    }

    private func applyNewFrame(_ newFrame: CGRect, for hostingController: UIHostingController<AnyView>, animated: Bool) {
        if animated {
            UIView.animate(
                withDuration: Constants.standardAnimationDuration,
                delay: 0,
                usingSpringWithDamping: Constants.standardSpringDamping,
                initialSpringVelocity: Constants.standardSpringVelocity,
                options: .curveEaseOut
            ) {
                hostingController.view.frame = newFrame
            }
        } else {
            hostingController.view.frame = newFrame
        }
    }
    
    @objc public func addRunningApp(_ appName: String, appUUID: String, view: UIView?) {
        let appInfo = AppInfoProvider.shared.findAppInfo(appName: appName, dataUUID: appUUID)
        addRunningAppWithInfo(appInfo, appUUID: appUUID, view: view)
    }
    
    @objc public func removeRunningApp(_ appUUID: String) {
        guard isDockEnabled() else { return }
        
        DispatchQueue.main.async {
            withAnimation(Constants.appsAnimation) {
                self.apps.removeAll { $0.appUUID == appUUID }
            }
            
            if self.apps.isEmpty {
                self.hideDock()
            } else if self.isVisible {
                // The panel shrinks toward the edge the dock keeps to as the
                // icon goes, inside the frame it has, which then catches up,
                // so nothing jumps.
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.appsAnimationDuration) {
                    self.updateDockFrame(animated: false)
                }
            }
        }
    }
    
    @objc public func showDock() {
        guard isDockEnabled() else { return }
        guard !isVisible, let hostingController = hostingController else { return }
        
        guard let keyWindow = self.keyWindow else { return }
        
        DispatchQueue.main.async {
            self.isVisible = true
            
            let screenBounds = keyWindow.bounds
            let currentDockWidth = self.dockWidth
            let initialHeight = Constants.initialDockShowHeight
            
            // If not already in view hierarchy, add it
            if hostingController.view.superview == nil {
                keyWindow.addSubview(hostingController.view)
                hostingController.view.frame = CGRect(
                    x: screenBounds.width - currentDockWidth,
                    y: (screenBounds.height - initialHeight) / 2,
                    width: currentDockWidth,
                    height: initialHeight
                )
            }
            
            self.updateDockFrame(animated: false) 
            
            self.setupEdgeGestureRecognizers()
            
            hostingController.view.alpha = 0
            let initialScale = Constants.initialScale
            hostingController.view.transform = CGAffineTransform(scaleX: initialScale, y: initialScale)
            
            UIView.animate(
                withDuration: Constants.standardAnimationDuration,
                delay: 0,
                usingSpringWithDamping: Constants.showHideSpringDamping,
                initialSpringVelocity: Constants.showHideSpringVelocity,
                options: .curveEaseOut
            ) {
                hostingController.view.alpha = 1
                hostingController.view.transform = .identity
            }
        }
    }
    
    @objc public func hideDock() {
        guard isVisible, let hostingController = hostingController else { return }
        
        DispatchQueue.main.async {
            UIView.animate(
                withDuration: Constants.standardAnimationDuration,
                delay: 0,
                usingSpringWithDamping: Constants.showHideSpringDamping,
                initialSpringVelocity: Constants.showHideSpringVelocity,
                options: .curveEaseOut
            ) {
                hostingController.view.alpha = 0
                let finalScale = Constants.initialScale
                hostingController.view.transform = CGAffineTransform(scaleX: finalScale, y: finalScale)
                // Move off-screen to hide, but keep in view hierarchy
                guard let screenBounds = self.keyWindow?.bounds else { return }
                let currentDockWidth = self.dockWidth
                let targetX = self.calculateTargetX(isDockHidden: true, isOnRightSide: hostingController.view.frame.midX > screenBounds.width / 2, dockWidth: currentDockWidth, screenWidth: screenBounds.width)
                let targetY = hostingController.view.frame.origin.y // Keep current Y
                hostingController.view.frame.origin = CGPoint(x: targetX, y: targetY)
            } completion: { _ in
                self.isVisible = false
                hostingController.view.transform = .identity
            }
        }
    }

    @objc public func updateFrameAfterAnimation(finalOffset: CGSize) {
        guard let hostingController = self.hostingController else { return }
        
        let newFrame = hostingController.view.frame.offsetBy(dx: finalOffset.width, dy: finalOffset.height)
        
        hostingController.view.frame = newFrame
    }

    
    
    // Find and bring corresponding multitask view to front
    func bringMultitaskViewToFront(uuid: String, from center: CGPoint? = nil) -> Bool {
        guard let windowScene = keyWindow?.windowScene else {
            return false
        }
        attachWindowHostingView()

        guard let targetView = apps.first(where: { $0.appUUID == uuid })?.view,
              let window = windowScene.windows.first else {
            return false
        }
        passURLSchemeToView(targetView)
        animateViewAppearance(targetView, from: center, in: window)
        return true
    }

    private func passURLSchemeToView(_ view: UIView) {
        if let launchUrl = UserDefaults.standard.string(forKey: "launchAppUrlScheme") {
            UserDefaults.standard.removeObject(forKey: "launchAppUrlScheme")
            if let decoratedVC = view._viewDelegate() as? DecoratedAppSceneViewController {
                decoratedVC.appSceneVC.openURLScheme(launchUrl)
            }
        }
    }

    private func animateViewAppearance(_ view: UIView, from center: CGPoint?, in window: UIWindow) {
        let isHidden = view.isHidden || view.alpha < 0.1
        let decoratedVC = view._viewDelegate() as? DecoratedAppSceneViewController
        let isMaximized = decoratedVC?.isMaximized ?? false
        
        // when a fullscreen multitask app is brought to front, optionally hide other windows
        if UserDefaults.lcShared().bool(forKey: "LCMaxOneAppOnStage") && isMaximized {
            MultitaskDockManager.shared.minimizeAllWindows(except: decoratedVC)
        }
        
        if isHidden {
            view.layer.removeAllAnimations()
            view.isHidden = true
            view.transform = .identity
            let origFrame = view.frame
            let pipManager = PiPManager.shared!
            if let decoratedVC = view._viewDelegate(), pipManager.isPiP(withDecoratedVC: decoratedVC) {
                pipManager.stopPiP()
            } else if let decoratedVC {
                // Back out of its icon in the dock, the way it went in. Its
                // frame stays as it is, so the app isn't resized on the way.
                self.bringViewToFront(view, in: window)
                decoratedVC.restoreFromDock()
                decoratedVC.revealWindowControls()
                return
            } else {
                view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                view.isHidden = false
                let smaller = min(view.frame.size.width, view.frame.size.height)
                view.frame.size = CGSize(width: smaller, height: smaller)
                if let center { view.center = center }
            }
            
            self.bringViewToFront(view, in: window)
            // A full-screen window has no title bar; coming forward from the
            // dock shows its window controls for a moment.
            decoratedVC?.revealWindowControls()
            UIView.animate(
                withDuration: Constants.standardAnimationDuration,
                delay: 0,
                usingSpringWithDamping: 1.0,
                initialSpringVelocity: 0,
                options: .curveEaseInOut,
                animations: {
                    view.alpha = 1.0
                    view.transform = .identity
                    view.frame = origFrame
                }
            )
        } else {
            bringViewToFront(view, in: window)
            decoratedVC?.revealWindowControls()
            
            UIView.animate(withDuration: Constants.shortAnimationDuration1, animations: {
                let scale = Constants.bringToFrontScale
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
            }) { _ in
                UIView.animate(withDuration: Constants.shortAnimationDuration2) {
                    view.transform = .identity
                }
            }
        }
    }

    private func bringViewToFront(_ view: UIView, in window: UIWindow) {
        if let superview = view.superview {
            superview.bringSubviewToFront(view)
        }
        if let windowSuperview = window.superview {
            windowSuperview.bringSubviewToFront(window)
        }
    }

    @objc public func addRunningAppWithInfo(_ appInfo: LCAppInfo?, appUUID: String, view: UIView?) {
        guard isDockEnabled() else { return }
        
        if apps.contains(where: { $0.appUUID == appUUID }) {
            return
        }
        
        let appName = appInfo?.displayName() ?? "Unknown App"
        let appModel = DockAppModel(appName: appName, appUUID: appUUID, appInfo: appInfo, view: view)
        
        DispatchQueue.main.async {
            withAnimation(Constants.appsAnimation) {
                self.apps.append(appModel)
            }
            
            if self.apps.count == 1 {
                self.showDock()
            } else if self.isVisible {
                // The frame grows at once, away from the edge the dock keeps
                // to, and the icon comes into the room it makes.
                self.updateDockFrame(animated: false)
            }
        }
    }
    
    @objc public func minimizeAllWindows(except: DecoratedAppSceneViewController? = nil) {
        DispatchQueue.main.async {
            self.apps.forEach { app in
                if let vc = app.view?._viewDelegate() as? DecoratedAppSceneViewController,
                   vc != except {
                    app.view?.layer.removeAllAnimations()
                    vc.minimizeWindow()
                }
            }
        }
    }
    


    /// Where an app's icon sits in the dock, in `view`'s coordinates, for a
    /// window going into it or coming back out of it, as a Mac window goes
    /// into the Dock. While the dock is tucked away, the tab it's tucked
    /// into. Null when the dock isn't showing.
    @objc public func iconFrame(forAppUUID appUUID: String, in view: UIView) -> CGRect {
        guard isVisible,
              let hostingView = hostingController?.view,
              let container = hostingView.superview,
              let index = apps.firstIndex(where: { $0.appUUID == appUUID }) else {
            return .null
        }
        let frame = hostingView.frame
        let rect: CGRect
        if isDockHidden {
            let visible = frame.intersection(container.bounds)
            guard !visible.isNull, !visible.isEmpty else { return .null }
            rect = CGRect(x: visible.midX - 12, y: visible.midY - 12, width: 24, height: 24)
        } else {
            // The panel fills the frame's height, with its icons centered
            // across it, one under another.
            let iconSize = adaptiveIconSize
            let y = frame.minY + panelPadding(for: dockWidth) + CGFloat(index) * (iconSize + Constants.dockContentSpacing)
            rect = CGRect(x: frame.midX - iconSize / 2, y: y, width: iconSize, height: iconSize)
        }
        return container.convert(rect, to: view)
    }

    /// Reads again which apps' windows are out of sight, as one is minimized
    /// or comes back.
    @objc public func refreshWindowVisibility() {
        DispatchQueue.main.async {
            let hidden = Set(self.apps.compactMap { app -> String? in
                guard let view = app.view else { return nil }
                return view.isHidden || view.alpha < 0.1 ? app.appUUID : nil
            })
            if hidden != self.hiddenAppUUIDs {
                self.hiddenAppUUIDs = hidden
            }
        }
    }

    @objc public func showDockFromHidden() {
        DispatchQueue.main.async {
            self.isDockHidden = false
            self.updateDockFrame()
            self.setupEdgeGestureRecognizers()
        }
    }
    
    @objc public func hideDockToSide() {
        DispatchQueue.main.async {
            self.isDockHidden = true
            self.updateDockFrame()
            self.setupEdgeGestureRecognizers()
        }
    }
    
    // Add edge gesture recognition areas when dock is hidden
    private func setupEdgeGestureRecognizers() {
        guard let keyWindow = self.keyWindow else { return }
        
        keyWindow.gestureRecognizers?.removeAll { gesture in
            return gesture is UITapGestureRecognizer || gesture is UIScreenEdgePanGestureRecognizer
        }
        
        if isDockHidden {
            let leftEdgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeSwipe(_:)))
            leftEdgeGesture.edges = .left
            keyWindow.addGestureRecognizer(leftEdgeGesture)
            
            let rightEdgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeSwipe(_:)))
            rightEdgeGesture.edges = .right
            keyWindow.addGestureRecognizer(rightEdgeGesture)
        }
    }
    
    @objc private func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard isDockHidden, gesture.state == .began || gesture.state == .changed else {
            return
        }
        
        let translation = gesture.translation(in: gesture.view)
        let swipeDistance = abs(translation.x)
        
        if swipeDistance > Constants.edgeSwipeThreshold {
            showDockFromHidden()
        }
    }
    
    // MARK: - Multitask Mode Check
    private func isDockEnabled() -> Bool {
        let multitaskMode = MultitaskMode(rawValue: LCUtils.appGroupUserDefault.integer(forKey: "LCMultitaskMode")) ?? .virtualWindow
        return multitaskMode == .virtualWindow
    }
}

// MARK: - SwiftUI Dock View
@available(iOS 16.0, *)
public struct MultitaskDockSwiftView: View {
    @EnvironmentObject var dockManager: MultitaskDockManager
    @State private var dragOffset = CGSize.zero
    @State private var isMoving: Bool = false
    /// Whether the icons wiggle with a minus badge that closes each app's
    /// window, after a long press on one of them.
    @State private var isWigglingApps = false

    /// The space inside the glass, the same the manager sizes the dock with.
    private var dynamicPadding: CGFloat {
        dockManager.panelPadding(for: dockManager.dockWidth)
    }

    /// The panel's corner radius: half a round icon plus the padding around
    /// it, so the panel is a pill whose ends run around the icons.
    private var panelCornerRadius: CGFloat {
        dockManager.adaptiveIconSize / 2 + dynamicPadding
    }

    /// The panel's width: one icon and the padding at its sides.
    private var panelWidth: CGFloat {
        dockManager.adaptiveIconSize + dynamicPadding * 2
    }

    /// Where the panel sits in the dock's frame: against the edge the dock
    /// keeps to, so it grows and shrinks from there as apps come and go.
    private var panelAlignment: Alignment {
        switch dockManager.dockAnchor {
        case .top:
            return .top
        case .middle:
            return .center
        case .bottom:
            return .bottom
        }
    }

    /// Whether the dock is on the screen's right edge, worked out as the
    /// manager does when it places the dock.
    private var isOnRightEdge: Bool {
        guard let frame = dockManager.hostingController?.view.frame, !frame.isEmpty,
              let screenWidth = dockManager.keyWindow?.bounds.width else {
            return true
        }
        return frame.midX > screenWidth / 2
    }

    /// How much of the panel stays on screen while the dock is tucked into
    /// the edge. The chevron is centered in it.
    private var tuckedVisibleWidth: CGFloat {
        guard let frame = dockManager.hostingController?.view.frame,
              let screen = dockManager.keyWindow?.bounds else {
            return 0
        }
        let visibleFrameWidth = isOnRightEdge ? screen.maxX - frame.minX : frame.maxX - screen.minX
        let panelInset = (frame.width - panelWidth) / 2
        return min(max(visibleFrameWidth - panelInset, 0), panelWidth)
    }

    /// The open dock: the apps, each with the dot the Mac's dock puts under
    /// an app whose window shows.
    private var panel: some View {
        VStack(spacing: MultitaskDockManager.Constants.dockContentSpacing) {
            ForEach(dockManager.apps) { app in
                AppIconView(app: app, isWiggling: $isWigglingApps)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .padding(dynamicPadding)
        // Room under the last app for its dot.
        .padding(.bottom, MultitaskDockManager.Constants.indicatorSpace)
        // In wiggle mode a tap on the dock outside its icons ends it.
        .background {
            if isWigglingApps {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture {
                        isWigglingApps = false
                    }
                    .accessibilityHidden(true)
            }
        }
        // The whole panel takes drags.
        .contentShape(.rect(cornerRadius: panelCornerRadius))
        .transition(.opacity)
    }

    /// The dock tucked into its side, like a Picture in Picture window
    /// tucked away: a short tab of its glass with a chevron pointing back
    /// onto the screen. A tap or a pull brings the dock back.
    private var tuckedTab: some View {
        Image(systemName: isOnRightEdge ? "chevron.compact.left" : "chevron.compact.right")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: tuckedVisibleWidth)
            .frame(width: panelWidth, height: MultitaskDockManager.Constants.tuckedTabHeight, alignment: isOnRightEdge ? .leading : .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Show Dock")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                dockManager.showDockFromHidden()
            }
            .transition(.opacity)
    }

    public var body: some View {
        GeometryReader { g in
            Group {
                if dockManager.isDockHidden {
                    tuckedTab
                } else {
                    panel
                }
            }
            .modifier { content in
                if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
                    content.glassEffect(.regular, in: .rect(cornerRadius: panelCornerRadius))
                } else {
                    content.background {
                        RoundedRectangle(cornerRadius: panelCornerRadius)
                            .fill(.ultraThinMaterial)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                    }
                }
            }
            // The dock stays dark over any wallpaper or app. It sits on a
            // physical edge of the screen, so it lays out left to right in
            // every language, which keeps the chevron on the visible side.
            .environment(\.colorScheme, .dark)
            .environment(\.layoutDirection, .leftToRight)
            .scaleEffect(dockManager.isVisible ? 1.0 : 0.8)
            .offset(dragOffset)
            .frame(width: g.size.width, height: g.size.height, alignment: panelAlignment)
        }
        // Tucked away, a tap anywhere on what shows of the dock brings it back.
        .overlay {
            if dockManager.isDockHidden {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture {
                        dockManager.showDockFromHidden()
                    }
                    .accessibilityHidden(true)
            }
        }



        .ignoresSafeArea()
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
            .onChanged { value in
                self.isMoving = true
                self.dragOffset = value.translation
            }
            .onEnded { value in
                self.isMoving = true
                let frame = dockManager.hostingController?.view.frame ?? .zero
                let settle = Animation.spring(response: MultitaskDockManager.Constants.longAnimationDuration, dampingFraction: MultitaskDockManager.Constants.standardSpringDamping)
                let duration = MultitaskDockManager.Constants.longAnimationDuration

                // Tucked away, a pull back onto the screen brings it out.
                // Anything else leaves it where it is.
                if dockManager.isDockHidden {
                    if dockManager.pullBringsDockOut(from: frame, translation: value.translation) {
                        dockManager.showDockFromHidden()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    withAnimation(settle) {
                        self.dragOffset = .zero
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        self.isMoving = false
                    }
                    return
                }

                // Pushed toward the edge it's on, it tucks into it, as Picture
                // in Picture does.
                if dockManager.dragTucksDock(from: frame, translation: value.translation, predicted: value.predictedEndTranslation) {
                    dockManager.hideDockToSide()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(settle) {
                        self.dragOffset = .zero
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        self.isMoving = false
                    }
                    return
                }

                // Otherwise it goes to the corner, or the middle of a side,
                // nearest where the throw was headed.
                let projected = frame.offsetBy(dx: value.predictedEndTranslation.width, dy: value.predictedEndTranslation.height)
                let origin = dockManager.snapOrigin(forProjected: projected)
                let newOffset = CGSize(width: origin.x - frame.origin.x, height: origin.y - frame.origin.y)
                withAnimation(settle) {
                    self.dragOffset = newOffset
                }
                UISelectionFeedbackGenerator().selectionChanged()
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    dockManager.updateFrameAfterAnimation(finalOffset: newOffset)
                    self.dragOffset = .zero
                    self.isMoving = false
                }
            }
        )
        .animation(.spring(response: MultitaskDockManager.Constants.standardAnimationDuration, dampingFraction: MultitaskDockManager.Constants.standardSpringDamping), value: dockManager.isDockHidden)
        .animation(.spring(response: MultitaskDockManager.Constants.longAnimationDuration, dampingFraction: MultitaskDockManager.Constants.standardSpringDamping), value: dockManager.dockWidth)
        .animation(.spring(response: MultitaskDockManager.Constants.longAnimationDuration, dampingFraction: MultitaskDockManager.Constants.standardSpringDamping), value: dockManager.settingsChanged)
        .animation(HomeDesign.modeChange, value: isWigglingApps)
        .sensoryFeedback(.impact(weight: .medium), trigger: isWigglingApps) { _, isWiggling in
            isWiggling
        }
        // Wiggle mode ends when the dock tucks into the edge or has no apps
        // left.
        .onChange(of: dockManager.isDockHidden) {
            isWigglingApps = false
        }
        .onChange(of: dockManager.apps.isEmpty) { _, isEmpty in
            if isEmpty {
                isWigglingApps = false
            }
        }
    }

    public init() {}
}

// MARK: - App Icon View
@available(iOS 16.0, *)
struct AppIconView: View {
    let app: DockAppModel
    /// Whether the dock's icons wiggle, each with a minus badge that closes
    /// its app's window.
    @Binding var isWiggling: Bool
    @State private var isPressed = false
    @State private var appIcon: UIImage?
    @State private var isLoading = true
    /// Whether the finger whose long press started wiggle mode is still
    /// down, so lifting it isn't taken for a tap.
    @State private var isHoldingAfterLongPress = false
    @EnvironmentObject var dockManager: MultitaskDockManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) var darkModeIcon = false

    private var iconSize: CGFloat {
        return dockManager.adaptiveIconSize
    }

    /// Whether the app's window is out of sight, minimized or in Picture in
    /// Picture.
    private var isWindowHidden: Bool {
        dockManager.hiddenAppUUIDs.contains(app.appUUID)
    }

    /// The size of the minus badge, smaller on a small dock.
    private var badgeSize: CGFloat {
        min(20, iconSize * 0.36)
    }

    /// A number that stays the same for this app, so its icon always
    /// wiggles its own way, as on the Home Screen.
    private var jiggleSeed: Int {
        app.appUUID.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    var body: some View {
        Group {
            if isLoading && appIcon == nil {
                LoadingIconView()
            } else if let icon = appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.12)
            }
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(.circle)
        // Faded while the window is out of sight; the dot below marks one
        // that shows, as on the Mac's dock.
        .opacity(isWindowHidden ? 0.5 : 1)
        .overlay(alignment: .bottom) {
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(y: 7)
                .opacity(isWindowHidden ? 0 : 1)
                .accessibilityHidden(true)
        }
        .animation(.easeInOut(duration: 0.2), value: isWindowHidden)
        .brightness(isPressed ? -0.08 : 0)
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: MultitaskDockManager.Constants.standardAnimationDuration), value: dockManager.settingsChanged)
        .onAppear {
            loadAppIcon()
        }
        .onChange(of: darkModeIcon) {
            loadAppIcon()
        }
        .onPressGesture(
            onPress: {
                isPressed = true
            },
            onCancel: {
                // The finger moved: it's dragging the dock.
                isPressed = false
                isHoldingAfterLongPress = false
            },
            onRelease: { location in
                release(at: location)
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5, maximumDistance: 5)
                .onEnded { _ in
                    startWiggling()
                }
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.appName)
        .accessibilityValue(isWindowHidden ? "Minimized" : "Open")
        .accessibilityAddTraits(.isButton)
        // The badge sits over the icon, outside its gestures, so a tap on it
        // only closes the window. It stays inside the icon's corner, since
        // the dock's window may cut off anything past the panel.
        .overlay(alignment: .topLeading) {
            if isWiggling {
                Button(action: closeAppWindow) {
                    Label("Close \(app.appName)", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .font(.system(size: badgeSize * 0.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(.black.opacity(0.3), in: .circle)
                        .background(.ultraThinMaterial, in: .circle)
                        // A little room around the badge takes the tap too.
                        .padding(4)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .homeJiggle(isActive: isWiggling && !reduceMotion, seed: jiggleSeed)
    }

    /// Lifting the finger off the icon brings the app's window forward, or
    /// in wiggle mode only ends it.
    private func release(at location: CGPoint) {
        isPressed = false
        if isHoldingAfterLongPress {
            isHoldingAfterLongPress = false
            return
        }
        if isWiggling {
            isWiggling = false
            return
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        let _ = dockManager.bringMultitaskViewToFront(uuid: app.appUUID, from: location)
    }

    /// Starts wiggle mode from a long press on the icon, while the finger is
    /// still down.
    private func startWiggling() {
        isPressed = false
        isHoldingAfterLongPress = true
        isWiggling = true
    }

    /// Closes the app's window, as its red dot does, which also takes the
    /// app out of the dock.
    private func closeAppWindow() {
        (app.view?._viewDelegate() as? DecoratedAppSceneViewController)?.closeWindow()
    }

    /// Shows the app's Home Screen icon: the app's own image, unmasked, so
    /// the dock rounds it as the Home Screen does, rather than the icon with
    /// IconServices' mask and rim. One not drawn yet is drawn off the main
    /// thread.
    private func loadAppIcon() {
        if let appInfo = app.appInfo {
            showIcon(of: appInfo)
            return
        }
        let appName = app.appName
        let appUUID = app.appUUID
        // Finding the app can read the disk, so it's done off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppInfoProvider.shared.findAppInfo(appName: appName, dataUUID: appUUID)
            DispatchQueue.main.async {
                if let found {
                    showIcon(of: found)
                } else {
                    isLoading = false
                }
            }
        }
    }

    private func showIcon(of appInfo: LCAppInfo) {
        let isDark = darkModeIcon
        if let icon = appInfo.cachedHomeScreenIconIsDarkIcon(isDark) {
            appIcon = icon
            isLoading = false
            return
        }
        appInfo.drawHomeScreenIconIsDarkIcon(isDark) {
            appIcon = appInfo.cachedHomeScreenIconIsDarkIcon(isDark)
            isLoading = false
        }
    }
}

// MARK: - Press Gesture Helper
extension View {
    /// A press that lights up as the finger lands and acts as it lifts, but
    /// only for a tap. A finger that moves is dragging the dock, so the press
    /// lets go instead.
    func onPressGesture(onPress: @escaping () -> Void, onCancel: @escaping () -> Void, onRelease: @escaping (_ location: CGPoint) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if value.translation == CGSize.zero {
                        onPress()
                    } else if hypot(value.translation.width, value.translation.height) > MultitaskDockManager.Constants.tapSlop {
                        onCancel()
                    }
                }
                .onEnded { value in
                    if hypot(value.translation.width, value.translation.height) > MultitaskDockManager.Constants.tapSlop {
                        onCancel()
                    } else {
                        onRelease(value.startLocation)
                    }
                }
        )
    }
}

// MARK: - Loading Icon View
struct LoadingIconView: View {
    var body: some View {
        Circle()
            .fill(.white.opacity(0.12))
            .overlay {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
    }
}

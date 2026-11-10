import UIKit
import SwiftUI

@objc class AppDelegate: UIResponder, UIApplicationDelegate {
        
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? ) -> Bool {
        application.shortcutItems = nil
        UserDefaults.standard.removeObject(forKey: "LCNeedToAcquireJIT")
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            // Fix launching app if user opens JIT waiting dialog and kills the app. Won't trigger normally.
            if DataManager.shared.model.isJITModalOpen && !UserDefaults.standard.bool(forKey: "LCKeepSelectedWhenQuit"){
                UserDefaults.standard.removeObject(forKey: "selected")
                UserDefaults.standard.removeObject(forKey: "selectedContainer")
            }
        }
        
        // allow new scene pop up as a new fullscreen window
        method_exchangeImplementations(
            class_getInstanceMethod(UIApplication.self, #selector(UIApplication.requestSceneSessionActivation(_ :userActivity:options:errorHandler:)))!,
            class_getInstanceMethod(UIApplication.self, #selector(UIApplication.hook_requestSceneSessionActivation(_:userActivity:options:errorHandler:)))!)

        // remove symbol caches if user upgraded iOS
        if let lastIOSBuildVersion = LCUtils.appGroupUserDefault.string(forKey: "LCLastIOSBuildVersion"),
           let currentVersion = UIDevice.current.buildVersion,
           lastIOSBuildVersion == currentVersion {
            
        } else {
            LCUtils.appGroupUserDefault.removeObject(forKey: "symbolOffsetCache")
            LCUtils.appGroupUserDefault.setValue(UIDevice.current.buildVersion, forKey: "LCLastIOSBuildVersion")
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
}

class SceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject { // Make SceneDelegate conform ObservableObject
    var window: UIWindow?
    /// Which way the scene shows its interface, which an iPad's Home button
    /// follows: see HomeButtonEdge.
    @Published private(set) var interfaceOrientation = UIInterfaceOrientation.portrait
    private var geometryObservation: NSKeyValueObservation?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        self.window = (scene as? UIWindowScene)?.keyWindow
        // Turning an iPad all the way round leaves the window's size as it
        // was, so its geometry tells which way it now shows.
        geometryObservation = (scene as? UIWindowScene)?.observe(\.effectiveGeometry, options: [.initial, .new]) { [weak self] scene, _ in
            let orientation = scene.effectiveGeometry.interfaceOrientation
            DispatchQueue.main.async {
                if self?.interfaceOrientation != orientation {
                    self?.interfaceOrientation = orientation
                }
            }
        }
    }

}


@objc extension UIApplication {
    
    func hook_requestSceneSessionActivation(
        _ sceneSession: UISceneSession?,
        userActivity: NSUserActivity?,
        options: UIScene.ActivationRequestOptions?,
        errorHandler: ((any Error) -> Void)? = nil
    ) {
        // Full screen when the window in front is. With several scenes no
        // window may be key, such as while a restored app window reopens the
        // main one at launch, and then the options go through as they are.
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let frontScene = scenes.first { $0.activationState == .foregroundActive && $0.keyWindow != nil }
            ?? scenes.first { $0.keyWindow != nil }
        var newOptions = options
        if let frontScene, let frontWindow = frontScene.keyWindow {
            let fullScreenOptions = options ?? UIScene.ActivationRequestOptions()
            fullScreenOptions._setRequestFullscreen(frontWindow.bounds == frontScene.screen.bounds)
            newOptions = fullScreenOptions
        }
        self.hook_requestSceneSessionActivation(sceneSession, userActivity: userActivity, options: newOptions, errorHandler: errorHandler)
    }
    
}

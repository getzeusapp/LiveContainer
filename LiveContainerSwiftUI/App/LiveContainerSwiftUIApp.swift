//
//  LiveContainerSwiftUIApp.swift
//  LiveContainer
//
//  Created by s s on 2025/5/16.
//
import SwiftUI

@main
struct LiveContainerSwiftUIApp : SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator: AppLaunchCoordinator
    @State private var router: HomeRouter
    @State private var home: HomeScreenModel
    @State private var onboarding: OnboardingModel
    @State private var wallpaper = WallpaperStore()
    @State private var systemAppearance = SystemAppearance()
    
    init() {
        let fm = FileManager()
        var tempAppDataFolderNames : [String] = []
        var tempTweakFolderNames : [String] = []
        
        var tempApps: [LCAppModel] = []
        var tempArm32EmuApps: [LCAppModel] = []
        var tempHiddenApps: [LCAppModel] = []
        var tempURLSchemes: Set<String>? = DataManager.shared.model.multiLCStatus != 2 ? Set() : nil
        Self.moveGuestSettingsToAppGroup()

        do {
            // load apps
            try fm.createDirectory(at: LCPath.bundlePath, withIntermediateDirectories: true)
            // Delete what a replace that stopped halfway left behind.
            AppBundleSwap.recover(in: LCPath.bundlePath)
            let appDirs = try fm.contentsOfDirectory(atPath: LCPath.bundlePath.path)
            for appDir in appDirs {
                if !appDir.hasSuffix(".app") {
                    continue
                }
                let newApp = LCAppInfo(bundlePath: "\(LCPath.bundlePath.path)/\(appDir)")!
                newApp.relativeBundlePath = appDir
                newApp.isShared = false
                let model = LCAppModel(appInfo: newApp)
                if newApp.isHidden {
                    tempHiddenApps.append(model)
                } else {
                    tempApps.append(model)
                    tempURLSchemes?.formUnion(newApp.urlSchemes() as? [String] ?? [])
                }
                if newApp.is32bitEmulator {
                    tempArm32EmuApps.append(model)
                }
            }
            if LCPath.lcGroupDocPath != LCPath.docPath {
                try fm.createDirectory(at: LCPath.lcGroupBundlePath, withIntermediateDirectories: true)
                // Only the primary zContainer installs shared apps, so only it
                // cleans up after them: a secondary one starting while the
                // primary replaces a shared app would delete its new copy.
                if DataManager.shared.model.multiLCStatus != 2 {
                    AppBundleSwap.recover(in: LCPath.lcGroupBundlePath)
                }
                let appDirsShared = try fm.contentsOfDirectory(atPath: LCPath.lcGroupBundlePath.path)
                for appDir in appDirsShared {
                    if !appDir.hasSuffix(".app") {
                        continue
                    }
                    let newApp = LCAppInfo(bundlePath: "\(LCPath.lcGroupBundlePath.path)/\(appDir)")!
                    newApp.relativeBundlePath = appDir
                    newApp.isShared = true
                    let model = LCAppModel(appInfo: newApp)
                    if newApp.isHidden {
                        tempHiddenApps.append(model)
                    } else {
                        tempApps.append(model)
                        tempURLSchemes?.formUnion(newApp.urlSchemes() as? [String] ?? [])
                    }
                    if newApp.is32bitEmulator {
                        tempArm32EmuApps.append(model)
                    }
                }
            }
            // load document folders
            try fm.createDirectory(at: LCPath.dataPath, withIntermediateDirectories: true)
            let dataDirs = try fm.contentsOfDirectory(atPath: LCPath.dataPath.path)
            for dataDir in dataDirs {
                let dataDirUrl = LCPath.dataPath.appendingPathComponent(dataDir)
                if !dataDirUrl.hasDirectoryPath {
                    continue
                }
                tempAppDataFolderNames.append(dataDir)
            }
            
            // load tweak folders
            try fm.createDirectory(at: LCPath.tweakPath, withIntermediateDirectories: true)
            let tweakDirs = try fm.contentsOfDirectory(atPath: LCPath.tweakPath.path)
            for tweakDir in tweakDirs {
                let tweakDirUrl = LCPath.tweakPath.appendingPathComponent(tweakDir)
                if !tweakDirUrl.hasDirectoryPath {
                    continue
                }
                let folderName = tweakDir.hasSuffix(".disabled") ? String(tweakDir.dropLast(".disabled".count)) : tweakDir
                tempTweakFolderNames.append(folderName)
            }
        } catch {
            NSLog("[LC] error:\(error)")
        }
        
        DataManager.shared.model.apps = tempApps
        DataManager.shared.model.arm32EmuApps = tempArm32EmuApps
        DataManager.shared.model.hiddenApps = tempHiddenApps
        DataManager.shared.model.appDataFolderNames = tempAppDataFolderNames
        DataManager.shared.model.tweakFolderNames = tempTweakFolderNames
        if let tempURLSchemes {
            UserDefaults.lcShared().set(Array(tempURLSchemes), forKey: "LCGuestURLSchemes")
        }

        // Zeus's pink in place of iOS's blue, in every window, before the
        // first one opens.
        AppAccent.tintWindows()

        // Made after the apps are loaded, so the coordinator becomes their
        // delegate and the Home Screen places them.
        let coordinator = AppLaunchCoordinator(sharedModel: DataManager.shared.model)
        let onboarding = OnboardingModel(coordinator: coordinator)
        _coordinator = State(initialValue: coordinator)
        _onboarding = State(initialValue: onboarding)
        _router = State(initialValue: HomeRouter(coordinator: coordinator, onboarding: onboarding))
        _home = State(initialValue: HomeScreenModel(coordinator: coordinator))
    }
    
    var body: some Scene {
        WindowGroup(id: "Main") {
            AppRootView()
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .environmentObject(DataManager.shared.model)
                .environment(coordinator)
                .environment(router)
                .environment(home)
                .environment(onboarding)
                .environment(wallpaper)
                .environment(systemAppearance)
        }
        // zContainer shows one main window. On iPad, File > New Window and
        // Command-N would open a second one only for it to close again.
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        if UIApplication.shared.supportsMultipleScenes, #available(iOS 16.1, *) {
            WindowGroup(id: "appView", for: String.self) { $id in
                if let id {
                    MultitaskAppWindow(id: id)
                }
            }

        }
    }
    

    /// Moves the settings apps read as they run, saved in zContainer's own
    /// defaults before 1.0 (5), into the app group, where apps in multitasking
    /// windows, which run in the LiveProcess extension, can read them too.
    private static func moveGuestSettingsToAppGroup() {
        let group = LCUtils.appGroupUserDefault
        for key in ["LCSwitchAppWithoutAsking", "LCOpenWebPageWithoutAsking"] {
            guard let value = UserDefaults.standard.object(forKey: key) else {
                continue
            }
            if group.object(forKey: key) == nil {
                group.set(value, forKey: key)
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

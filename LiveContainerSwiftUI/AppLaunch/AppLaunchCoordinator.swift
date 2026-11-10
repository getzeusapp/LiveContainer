//
//  AppLaunchCoordinator.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Installs, launches, hides and removes the apps inside zContainer, whichever
/// screen asks. It is the delegate of every LCAppModel, so JIT launches and the
/// question about stopping multitasking apps work from any screen. It keeps
/// what its flows need to show (errors, questions, the JIT log, install
/// progress and the built-in browser), and the root view presents them with
/// `appLaunchPresentations(_:)`.
@MainActor
@Observable
final class AppLaunchCoordinator {
    /// The installed apps and the hidden-app state the flows work on.
    @ObservationIgnored let sharedModel: SharedModel

    /// Downloads the IPAs that install links point at. `downloadAlert(helper:)`
    /// shows its progress.
    @ObservationIgnored let downloadHelper = DownloadHelper()

    /// Runs after every install, replace and removal, so what depends on the
    /// installed apps follows them. HomeRouter sets it to write the list of
    /// apps Zeus reads.
    @ObservationIgnored var onAppsChanged: @MainActor () -> Void = {}

    /// The error to show, as the person reads it, or nil when there is none.
    var errorMessage: String?

    /// Whether an IPA is being installed: downloaded, unpacked, moved in and
    /// signed. Installs run one at a time. Install links that arrive meanwhile
    /// wait in onboarding's queue (HomeRouter), the queue's installs and IPAs
    /// picked in Files wait their turn (`waitForInstallTurn()`), and an
    /// install started some other way meanwhile, such as an itms-services
    /// link from the built-in browser or an `open-url` link, says zContainer
    /// is busy.
    var isInstalling = false
    /// How far unpacking and signing the current IPA has come, from 0 to 1.
    var installProgress: Float = 0
    @ObservationIgnored private var installObserver: NSKeyValueObservation?

    /// The choices `installReplacePrompt` offers while it is open.
    private(set) var installOptions: [AppReplaceOption] = []
    /// Asks whether a new app replaces an installed app with its bundle ID.
    let installReplacePrompt = AppLaunchPrompt<AppReplaceOption>()
    /// The question `updatePrompt` asks while it is open.
    private(set) var updateConfirmation: AppUpdateConfirmation?
    /// Asks whether an installed app is replaced by another copy of it, such
    /// as "Update Delta 1.2 to 1.3?". True goes ahead.
    let updatePrompt = AppLaunchPrompt<Bool>()
    /// Asks whether to stop the multitasking apps to run an app the classic way.
    let runWhenMultitaskPrompt = AppLaunchPrompt<Bool>()
    /// Waits while a JIT enabler attaches to an app, and asks whether to launch it.
    let jitPrompt = AppLaunchPrompt<Bool>()
    /// What the JIT enabler has reported so far.
    private(set) var jitLog = ""

    /// The page the built-in browser shows.
    private(set) var webPageURL: URL?
    /// Whether the built-in browser is on screen.
    var isShowingWebPage = false

    /// Goes up by one each time an app asks to close the screen that shows its
    /// settings, which it does before it hides itself. Screens that show an
    /// app's settings close them when this changes.
    private(set) var appSettingsCloseRequests = 0

    /// Makes the coordinator the delegate of every app already loaded, and
    /// deletes what installs cut short left in tmp.
    init(sharedModel: SharedModel) {
        self.sharedModel = sharedModel
        for app in sharedModel.apps + sharedModel.hiddenApps {
            app.delegate = self
        }
        Self.removeLeftoverInstallFolders()
    }

    /// Carries out an app link, as HomeRouter hands them over.
    func handle(_ link: AppLink) {
        switch link {
        case .install(let address):
            // Claimed now, not in the Task, so a link that arrives in the same
            // turn finds isInstalling set and waits in onboarding's queue.
            guard let url = claimInstall(urlStr: address) else {
                return
            }
            Task { await install(claimed: url) }
        case let .launch(bundleName, containerFolderName, url, forceJIT):
            Task { await launchAppWithBundleId(bundleId: bundleName, container: containerFolderName, urlStr: url, forceJIT: forceJIT) }
        case .openURL(let target):
            Task { await openWebView(urlString: target) }
        }
    }

    // MARK: Installing

    /// Installs from a link the person typed: an `itms-services://` link
    /// through its manifest, anything else as the IPA's own address.
    func install(fromAddress address: String) async {
        if let url = URL(string: address), url.scheme?.lowercased() == "itms-services" {
            await installFromPlist(urlStr: address)
        } else {
            await installFromUrl(urlStr: address)
        }
    }

    /// Installs an IPA the person picked in Files once no other install runs,
    /// then deletes the copy the file importer made of it, however the install
    /// ended.
    func startInstallApp(_ fileUrl: URL) async {
        await waitForInstallTurn()
        isInstalling = true
        defer { isInstalling = false }
        do {
            try await installIpaFile(fileUrl)
        } catch {
            errorMessage = error.localizedDescription
        }
        try? FileManager.default.removeItem(at: fileUrl)
    }

    /// Installs the app an `itms-services://` link or a manifest URL points at:
    /// reads the manifest, then installs its software package. Both have to be
    /// web addresses.
    func installFromPlist(urlStr: String) async {
        if isInstalling {
            errorMessage = "zc.install.busy".loc
            return
        }
        if sharedModel.multiLCStatus == 2 {
            errorMessage = "lc.appList.manageInPrimaryTip".loc
            return
        }

        var plistUrlStr = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if plistUrlStr.lowercased().hasPrefix("itms-services://") {
            guard let manifestURL = URLComponents(string: plistUrlStr)?.queryItems?.first(where: { $0.name == "url" })?.value else {
                errorMessage = "lc.appList.plistInvalidError".loc
                return
            }
            plistUrlStr = manifestURL
        }

        guard let plistUrl = URL(string: plistUrlStr), Self.isWebAddress(plistUrl) else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: plistUrl)
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let items = plist["items"] as? [[String: Any]],
                  let assets = items.first?["assets"] as? [[String: Any]] else {
                errorMessage = "lc.appList.plistParseError".loc
                return
            }
            let ipaUrlStr = assets.lazy.compactMap { asset -> String? in
                guard asset["kind"] as? String == "software-package" else {
                    return nil
                }
                return asset["url"] as? String
            }.first
            guard let ipaUrlStr, let ipaURL = URL(string: ipaUrlStr), Self.isWebAddress(ipaURL) else {
                errorMessage = "lc.appList.plistNoIpaError".loc
                return
            }
            await installFromUrl(urlStr: ipaUrlStr)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Installs the IPA at a web address, downloading it first, or at a file
    /// URL, such as an IPA opened with zContainer or shared to it. Any other
    /// scheme is turned away.
    func installFromUrl(urlStr: String) async {
        guard let installUrl = claimInstall(urlStr: urlStr) else {
            return
        }
        await install(claimed: installUrl)
    }

    /// Marks an install from `urlStr` as running and returns its URL, or says
    /// why it can't start (busy, a secondary zContainer, or an address that is
    /// neither a file URL nor a web address) and returns nil. It never
    /// suspends, so nothing can start an install between the check and the
    /// claim.
    private func claimInstall(urlStr: String) -> URL? {
        if isInstalling {
            errorMessage = "zc.install.busy".loc
            return nil
        }
        if sharedModel.multiLCStatus == 2 {
            errorMessage = "lc.appList.manageInPrimaryTip".loc
            return nil
        }
        guard let installUrl = URL(string: urlStr), installUrl.isFileURL || Self.isWebAddress(installUrl) else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return nil
        }
        isInstalling = true
        return installUrl
    }

    /// Installs from a URL `claimInstall(urlStr:)` claimed, and ends the
    /// claim however the install ends.
    private func install(claimed installUrl: URL) async {
        defer { isInstalling = false }

        if installUrl.isFileURL {
            await installLocalIpa(installUrl)
            return
        }

        // A folder of its own for each download, whatever the address ends
        // in, deleted however the install ends.
        let fileManager = FileManager.default
        let downloadFolder = fileManager.temporaryDirectory
            .appending(path: Self.downloadFolderPrefix + UUID().uuidString, directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: downloadFolder) }
        do {
            try fileManager.createDirectory(at: downloadFolder, withIntermediateDirectories: true)
            let destinationURL = downloadFolder.appending(path: "App.ipa", directoryHint: .notDirectory)
            try await downloadHelper.download(url: installUrl, to: destinationURL)
            if downloadHelper.cancelled {
                return
            }
            try await installIpaFile(destinationURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// What the folder each download goes in is named, before its UUID.
    private static let downloadFolderPrefix = "Install-"
    /// What the folder each install unpacks its IPA in is named, before its
    /// UUID.
    private nonisolated static let unpackFolderPrefix = "Unpack-"

    /// Deletes the download and unpack folders of installs that zContainer
    /// stopping cut short, such as iOS ending it halfway through unpacking a
    /// large IPA, since their own cleanup never ran. It also deletes what
    /// `moveToTmp(_:)` moved there and zContainer stopped before deleting:
    /// old apps a swap left behind, apps `AppBundleSwap.recover(in:)` cleared
    /// away at this launch, removed apps and their data, and containers
    /// removed and data deleted in an app's settings. It runs before any
    /// install can start, so none of the folders it finds is in use; only the
    /// deleting happens in the background. Guest apps share tmp, so only
    /// folders named the way installs name them go.
    private static func removeLeftoverInstallFolders() {
        let tmp = FileManager.default.temporaryDirectory
        let names = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path)) ?? []
        let leftovers = names.filter(isInstallFolderName).map {
            tmp.appending(path: $0, directoryHint: .isDirectory)
        }
        guard !leftovers.isEmpty else {
            return
        }
        Task.detached(priority: .utility) {
            let fileManager = FileManager()
            for url in leftovers {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Moves a folder zContainer is done with, such as the old app a replace
    /// leaves behind, into tmp under a name `removeLeftoverInstallFolders()`
    /// deletes, so the deleting can wait. It's one rename, never a copy.
    /// - Returns: Where the folder went, or nil when it couldn't be moved and
    ///   is still at `url`.
    nonisolated static func moveToTmp(_ url: URL) -> URL? {
        let target = FileManager.default.temporaryDirectory
            .appending(path: unpackFolderPrefix + UUID().uuidString, directoryHint: .isDirectory)
        let moved = url.withUnsafeFileSystemRepresentation { sourcePath in
            target.withUnsafeFileSystemRepresentation { targetPath in
                guard let sourcePath, let targetPath else {
                    return false
                }
                return rename(sourcePath, targetPath) == 0
            }
        }
        return moved ? target : nil
    }

    /// Whether a name in tmp is one an install gives its download or unpack
    /// folder: a prefix and a UUID.
    private static func isInstallFolderName(_ name: String) -> Bool {
        [downloadFolderPrefix, unpackFolderPrefix].contains { prefix in
            name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
        }
    }

    /// Whether a URL is a web address, the only kind zContainer downloads.
    private static func isWebAddress(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }

    /// Installs an IPA from a file URL. When zContainer can't read the file
    /// itself, it tries the bookmark the share extension leaves, when it
    /// names this file, and then security-scoped access. An IPA in the Inbox
    /// is deleted afterwards. The caller marks the install as running.
    /// - Returns: How the install ended, `.cancelled` when it failed and
    ///   `errorMessage` says why.
    @discardableResult
    func installLocalIpa(_ fileURL: URL, policy: AppInstallPolicy = .ask) async -> AppInstallOutcome {
        var installUrl = fileURL
        let fileExtension = installUrl.pathExtension.lowercased()
        if fileExtension != "ipa" && fileExtension != "tipa" {
            errorMessage = "lc.appList.urlFileIsNotIpaError".loc
            return .cancelled
        }

        let fm = FileManager.default
        var didStartAccessing = false
        if !fm.isReadableFile(atPath: installUrl.path),
           let shared = InstallLinkPolicy.sharedFileBookmark(for: installUrl) {
            installUrl = shared.url
            didStartAccessing = shared.url.startAccessingSecurityScopedResource()
        }

        if !fm.isReadableFile(atPath: installUrl.path) && !didStartAccessing {
            didStartAccessing = installUrl.startAccessingSecurityScopedResource()
        }
        if !fm.isReadableFile(atPath: installUrl.path) && !didStartAccessing {
            errorMessage = "lc.appList.ipaAccessError".loc
            return .cancelled
        }
        defer {
            if didStartAccessing {
                installUrl.stopAccessingSecurityScopedResource()
            }
        }

        var outcome = AppInstallOutcome.cancelled
        do {
            outcome = try await installIpaFile(installUrl, policy: policy)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let inboxURL = URL.documentsDirectory.appendingPathComponent("Inbox")
            if installUrl.deletingLastPathComponent().standardizedFileURL == inboxURL.standardizedFileURL {
                try fm.removeItem(at: installUrl)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return outcome
    }

    /// Unpacks an IPA, moves its app into the Applications folder, patches and
    /// signs it, and adds it to the Home Screen. When an app with the same
    /// bundle ID is installed, `policy` decides what happens: the three-way
    /// question, or for an update from Zeus a one-tap one. A replaced app keeps
    /// its data and settings, and its folder is swapped in one step, so
    /// zContainer stopping halfway never loses the link to its data. A signing
    /// problem doesn't stop the install: the app stays unsigned and the problem
    /// is shown.
    /// - Returns: The app added or replaced, or `.cancelled` when the person
    ///   kept what was installed.
    /// - Throws: Why nothing was installed, such as an IPA without an app, or
    ///   an `AppInstallError`.
    @discardableResult
    func installIpaFile(_ url: URL, policy: AppInstallPolicy = .ask) async throws -> AppInstallOutcome {
        // However the install ends, what depends on the installed apps
        // follows them.
        defer {
            refreshGuestURLSchemes()
            onAppsChanged()
        }
        let fm = FileManager()

        let overallProgress = Progress.discreteProgress(totalUnitCount: 100)
        installProgress = 0
        installObserver = overallProgress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = Float(progress.fractionCompleted)
            Task { @MainActor in
                self?.installProgress = fraction
            }
        }
        let decompressProgress = Progress.discreteProgress(totalUnitCount: 100)
        overallProgress.addChild(decompressProgress, withPendingUnitCount: 80)

        // A folder of its own for each install, deleted however it ends, in
        // the background, since an app left in it can hold thousands of
        // files.
        let unpackFolder = fm.temporaryDirectory.appending(path: Self.unpackFolderPrefix + UUID().uuidString, directoryHint: .isDirectory)
        try fm.createDirectory(at: unpackFolder, withIntermediateDirectories: true)
        defer { Task.detached(priority: .utility) { try? FileManager().removeItem(at: unpackFolder) } }

        guard await Self.unpack(url.path, into: unpackFolder.path, progress: decompressProgress) == 0 else {
            throw "lc.appList.urlFileIsNotIpaError".loc
        }

        let payloadPath = unpackFolder.appending(path: "Payload", directoryHint: .isDirectory)
        // An entry can itself be a symbolic link, and one here would point the
        // move, patch and signing below at another app's files.
        let isSymbolicLink = { (url: URL) in
            (try? fm.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType == .typeSymbolicLink
        }
        let payloadContents = isSymbolicLink(payloadPath) ? [] : (try? fm.contentsOfDirectory(atPath: payloadPath.path)) ?? []
        guard let appBundleName = payloadContents.first(where: { $0.hasSuffix(".app") }) else {
            throw "lc.appList.bundleNotFondError".loc
        }
        let appFolderPath = payloadPath.appending(path: appBundleName, directoryHint: .isDirectory)
        guard !isSymbolicLink(appFolderPath) else {
            throw "lc.appList.bundleNotFondError".loc
        }
        // zContainer writes an app's settings itself: the old app's for a
        // replace, its own defaults for a new app. Settings the IPA carries
        // would pick the app's data folders and bundle ID, so they go: an
        // LCAppInfo.plist, and the keys an old LiveContainer kept in
        // Info.plist, which reading the app moves into that file.
        let carriedSettings = appFolderPath.appending(path: "LCAppInfo.plist", directoryHint: .notDirectory)
        try? fm.removeItem(at: carriedSettings)
        var readAppInfo = LCAppInfo(bundlePath: appFolderPath.path)
        if fm.fileExists(atPath: carriedSettings.path) {
            try? fm.removeItem(at: carriedSettings)
            readAppInfo = LCAppInfo(bundlePath: appFolderPath.path)
        }
        guard let newAppInfo = readAppInfo,
              let bundleIdentifier = newAppInfo.bundleIdentifier() else {
            throw "lc.appList.infoPlistCannotReadError".loc
        }
        // An executable zContainer can't run, like an encrypted one, is turned
        // away before anything is asked about it, and before it could take
        // the place of a copy that works.
        if let problem = newAppInfo.executableProblem() {
            throw problem
        }
        // The bundle ID names the app's folder.
        let folderStem = bundleIdentifier.sanitizeNonACSII()
        guard Self.canNameFolder(folderStem) else {
            throw AppInstallError.invalidBundleIdentifier
        }
        // Patching opens whatever path the executable's name leads to, so the
        // name has to be one file right inside the app. Reading the app above
        // may have taken it from LCBundleExecutable, and reading it again
        // takes it from there once more if that change wasn't saved, so both
        // are checked.
        let unpackedInfo = NSDictionary(contentsOf: appFolderPath.appending(path: "Info.plist", directoryHint: .notDirectory))
        for key in ["CFBundleExecutable", "LCBundleExecutable"] {
            guard let value = unpackedInfo?[key] else {
                continue
            }
            guard let executable = value as? String,
                  !executable.isEmpty, executable != ".", executable != "..",
                  !executable.contains("/"), !executable.contains("\0") else {
                throw "lc.appList.infoPlistCannotReadError".loc
            }
        }

        let choice: AppReplaceOption?
        switch policy {
        case .ask:
            choice = try await askWhereToInstall(newAppInfo, bundleIdentifier: bundleIdentifier, folderStem: folderStem)
        case let .fromZeus(expected, replacesFolder):
            guard bundleIdentifier == expected else {
                throw AppInstallError.bundleMismatch(expected: expected, found: bundleIdentifier)
            }
            choice = try await updateTarget(for: newAppInfo, bundleIdentifier: bundleIdentifier, folderStem: folderStem, replacesFolder: replacesFolder)
        }
        guard let choice else {
            return .cancelled
        }
        let appToReplace = choice.appToReplace
        if let appToReplace {
            // The app may have opened while a question showed.
            try checkNotRunning(appToReplace)
            // The old icon stays on the Home Screen until the new copy, at its
            // path, is signed and takes its place below, so it mustn't launch
            // or sign it.
            appToReplace.isAppRunning = true
        }
        // Once replaced, the old model stands for an app that's gone, so it
        // stays marked: a tap still waiting on Face ID can't run it on the new
        // copy.
        var isOldAppReplaced = false
        defer {
            if !isOldAppReplaced {
                appToReplace?.isAppRunning = false
            }
        }

        let finalNewApp: LCAppInfo
        // The replaced app's settings as the new app takes them. Its icon still
        // works while the new app signs, so what changes on it then follows the
        // new app below.
        var settingsAtSwap: NSDictionary?
        if let appToReplace {
            settingsAtSwap = NSDictionary(dictionary: appToReplace.appInfo.info())
            finalNewApp = try await replaceBundle(of: appToReplace, withAppAt: appFolderPath)
        } else {
            let outputFolder = LCPath.bundlePath.appending(path: choice.nameOfFolderToInstall, directoryHint: .isDirectory)
            try fm.moveItem(at: appFolderPath, to: outputFolder)
            guard let installedApp = LCAppInfo(bundlePath: outputFolder.path) else {
                throw "lc.appList.appInfoInitError".loc
            }
            installedApp.relativeBundlePath = choice.nameOfFolderToInstall
            if LCUtils.appGroupUserDefault.bool(forKey: "LCDontSignApp") {
                installedApp.dontSign = true
            }
            finalNewApp = installedApp
        }

        let (signSuccess, signError) = await Self.patchAndSign(finalNewApp, progress: overallProgress)
        if let appToReplace, let settingsAtSwap {
            Self.carryChanges(from: appToReplace.appInfo, since: settingsAtSwap, to: finalNewApp)
        }
        // The app stays installed, unsigned, when signing failed.
        if let signError {
            errorMessage = signSuccess ? "\("lc.appList.signSuccessWithError".loc)\n\n\(signError)" : signError.loc
        }

        let newAppModel: LCAppModel
        if let appToReplace {
            // It took the replaced app's settings before the swap, and what
            // changed on them while it signed.
            newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
            // One change to the list, so the Home Screen sees the app swapped
            // in place and its icon keeps its slot, rather than seeing it
            // leave and come back at the end.
            if appToReplace.uiIsHidden {
                Self.replace(appToReplace, with: newAppModel, in: &sharedModel.hiddenApps)
            } else {
                Self.replace(appToReplace, with: newAppModel, in: &sharedModel.apps)
            }
            // The emulator pickers list the new copy where the old one was.
            if finalNewApp.is32bitEmulator {
                Self.replace(appToReplace, with: newAppModel, in: &sharedModel.arm32EmuApps)
            } else {
                sharedModel.arm32EmuApps.removeAll { $0 == appToReplace }
            }
            isOldAppReplaced = true
            return .replaced(newAppModel)
        }

        // New apps spoof their SDK version by default.
        finalNewApp.spoofSDKVersion = true
        finalNewApp.installationDate = Date.now
        newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
        sharedModel.apps.append(newAppModel)
        if finalNewApp.is32bitEmulator {
            sharedModel.arm32EmuApps.append(newAppModel)
        }
        return .added(newAppModel)
    }

    /// Asks where an app goes when it's installed already, as every install
    /// but an update from Zeus does: in place of one of the copies, or as a
    /// new app in a folder of its own. Replacing a hidden app needs Face ID
    /// first. Choosing a copy checks it isn't open, and asks once more when
    /// the new app is older, since an app may not read data a newer version
    /// left.
    /// - Returns: The choice, or nil when the person kept what was installed.
    private func askWhereToInstall(_ incoming: LCAppInfo, bundleIdentifier: String, folderStem: String) async throws -> AppReplaceOption? {
        var copies = sharedModel.apps.filter { $0.appInfo.bundleIdentifier() == bundleIdentifier }
        if copies.isEmpty {
            copies = sharedModel.hiddenApps.filter { $0.appInfo.bundleIdentifier() == bundleIdentifier }
            // Replacing a hidden app needs Face ID first.
            if !copies.isEmpty && !sharedModel.isHiddenAppUnlocked {
                guard try await LCUtils.authenticateUser() else {
                    return nil
                }
            }
        }

        let folderName = "\(folderStem).app"
        let isFolderTaken = FileManager.default.fileExists(atPath: LCPath.bundlePath.appending(path: folderName).path)
        guard isFolderTaken || !copies.isEmpty else {
            return AppReplaceOption(isReplace: false, nameOfFolderToInstall: folderName)
        }

        // The folder exists or the app is installed already: ask which copy
        // the new app replaces, if any.
        var options = [AppReplaceOption(isReplace: false, nameOfFolderToInstall: Self.uniqueFolderName(for: folderStem))]
        for app in copies {
            options.append(AppReplaceOption(isReplace: true, nameOfFolderToInstall: app.appInfo.relativeBundlePath, appToReplace: app))
        }
        guard let choice = await askWhichToReplace(options) else {
            return nil
        }
        guard let target = choice.appToReplace else {
            return choice
        }
        try checkNotRunning(target)
        let question = confirmation(forReplacing: target, with: incoming)
        if question.kind == .downgrade, !(await confirm(question)) {
            return nil
        }
        return choice
    }

    /// Shows the replace question with these choices and waits for the answer,
    /// which is nil when the person kept what was installed.
    func askWhichToReplace(_ options: [AppReplaceOption]) async -> AppReplaceOption? {
        installOptions = options
        return await installReplacePrompt.ask()
    }

    /// Asks whether to replace an installed app, and returns true only when
    /// the person went ahead.
    func confirm(_ confirmation: AppUpdateConfirmation) async -> Bool {
        updateConfirmation = confirmation
        return await updatePrompt.ask() ?? false
    }

    /// The folder a new app goes into: one named after its bundle ID, or a
    /// unique one when that's taken.
    func newAppFolderName(for folderStem: String) -> String {
        let folderName = "\(folderStem).app"
        if FileManager.default.fileExists(atPath: LCPath.bundlePath.appending(path: folderName).path) {
            return Self.uniqueFolderName(for: folderStem)
        }
        return folderName
    }

    /// A folder named after the bundle ID and the time, for a copy installed
    /// beside the others.
    private static func uniqueFolderName(for folderStem: String) -> String {
        "\(folderStem)_\(Int(CFAbsoluteTimeGetCurrent())).app"
    }

    /// Whether a bundle ID, already stripped to ASCII, can name the app's
    /// folder: 1 to 255 characters, with no slash, colon or NUL, not starting
    /// with a dot.
    private static func canNameFolder(_ folderStem: String) -> Bool {
        (1...255).contains(folderStem.count)
            && !folderStem.hasPrefix(".")
            && !folderStem.contains { $0 == "/" || $0 == ":" || $0 == "\0" }
    }

    /// Puts `newApp` where `oldApp` is in `apps` in one change, or at the end
    /// when `oldApp` isn't there.
    private static func replace(_ oldApp: LCAppModel, with newApp: LCAppModel, in apps: inout [LCAppModel]) {
        if let index = apps.firstIndex(of: oldApp) {
            apps[index] = newApp
        } else {
            apps.append(newApp)
        }
    }

    /// Patches a new app and signs it when it needs it, off the main actor:
    /// patching and listing the bundle for ZSign read every file in it. ZSign
    /// then signs on its own queue, and its progress fills the last 20 units of
    /// `progress`. Returns whether it worked and what went wrong, if anything.
    @concurrent
    private nonisolated static func patchAndSign(_ app: LCAppInfo, progress: Progress) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            app.patchExecAndSignIfNeed(completionHandler: { success, error in
                continuation.resume(returning: (success, error))
            }, progressHandler: { signProgress in
                if let signProgress {
                    progress.addChild(signProgress, withPendingUnitCount: 20)
                }
            }, forceSign: false)
        }
    }

    /// Unpacks an IPA off the main actor. Returns 0 when it worked.
    @concurrent
    private nonisolated static func unpack(_ path: String, into destination: String, progress: Progress) async -> Int32 {
        extract(path, destination, progress)
    }

    // MARK: Removing

    /// Deletes an app's files and takes it off the Home Screen. With
    /// `deletingData`, its containers go too, with their keychain items;
    /// otherwise they stay, unused, for when the app comes back. A container
    /// in a folder the person picked elsewhere stays where it is, and a
    /// container that can't be deleted doesn't keep the others or the
    /// keychain items from going. An app being signed is left as it is.
    func uninstall(_ app: LCAppModel, deletingData: Bool) async {
        // An app being signed, to launch it or because an update is taking
        // its place, keeps its files, just as a tap on it does nothing then.
        // A replaced app's model stays marked, so a removal question left open
        // through its update can't delete the new copy now at its path.
        guard !app.isAppRunning else {
            return
        }
        // Nor one open in a multitasking window, which runs from these files.
        do {
            try checkNotRunning(app)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let appInfo = app.appInfo
        let containers = appInfo.containers
        defer {
            refreshGuestURLSchemes()
            onAppsChanged()
        }
        do {
            guard let bundlePath = appInfo.bundlePath() else {
                throw CocoaError(.fileNoSuchFile)
            }
            // The bundle leaves in one rename and is deleted in the
            // background, so the Home Screen doesn't wait for thousands of
            // files.
            if let removing = Self.moveToTmp(URL(filePath: bundlePath, directoryHint: .isDirectory)) {
                Task.detached(priority: .utility) {
                    try? FileManager().removeItem(at: removing)
                }
            } else {
                try FileManager.default.removeItem(atPath: bundlePath)
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        removeApp(app: app)

        guard deletingData else {
            return
        }
        for container in containers {
            let folderName = container.folderName
            // A shared app's containers are in the app group, which
            // `containerURL` knows. A folder name that isn't one folder in
            // the data folder, such as "../../Applications", would lead
            // outside it.
            let isOneFolder = !folderName.isEmpty && folderName != "." && folderName != ".."
                && !folderName.contains("/") && !folderName.contains("\0")
            if container.storageBookMark == nil, isOneFolder {
                if let removing = Self.moveToTmp(container.containerURL) {
                    Task.detached(priority: .utility) {
                        try? FileManager().removeItem(at: removing)
                    }
                } else {
                    try? FileManager.default.removeItem(at: container.containerURL)
                }
            }
            LCUtils.removeAppKeychain(dataUUID: folderName)
            sharedModel.appDataFolderNames.removeAll { $0 == folderName }
        }
    }

    /// Takes an uninstalled app off the Home Screen, after its files are gone.
    func removeApp(app: LCAppModel) {
        sharedModel.apps.removeAll { $0 == app }
        sharedModel.hiddenApps.removeAll { $0 == app }
        sharedModel.arm32EmuApps.removeAll { $0 == app }
    }

    // MARK: Launching

    /// Opens an app tapped on the Home Screen. When the app already runs in a
    /// multitasking window, that window comes forward. Otherwise a locked app
    /// asks for Face ID first, and the app runs: signed if it needs to be, then
    /// in a multitasking window or with zContainer turning into it, as its
    /// settings say, and with JIT when `forceJIT` asks, as Open with JIT does.
    /// `multitask` overrides the settings, as Open in Split Screen does.
    /// `willLaunch` runs just before zContainer turns into the app, after
    /// signing, so the Home Screen can zoom into it. Returns whether the app
    /// opened or came forward, which it doesn't when Face ID is cancelled or
    /// running it fails.
    @discardableResult
    func open(_ app: LCAppModel, forceJIT: Bool? = nil, multitask: Bool? = nil, willLaunch: (@MainActor () async -> Void)? = nil) async -> Bool {
        if #available(iOS 16.0, *),
           let folderName = app.uiSelectedContainer?.folderName,
           MultitaskManager.isUsing(container: folderName) {
            var found = false
            if #available(iOS 16.1, *) {
                found = MultitaskWindowManager.openExistingAppWindow(dataUUID: folderName)
            }
            if !found {
                found = MultitaskDockManager.shared.bringMultitaskViewToFront(uuid: folderName)
            }
            if found {
                return true
            }
        }

        // Opening an app can quit zContainer to turn into it, which would cut
        // the install short.
        guard !isInstalling else {
            errorMessage = "zc.install.busy".loc
            return false
        }

        if app.appInfo.isLocked && !sharedModel.isHiddenAppUnlocked {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return false
                }
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }

        do {
            try await app.runApp(multitask: multitask, forceJIT: forceJIT, willLaunch: willLaunch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Launches the app installed in the folder `bundleId`, as launch links and
    /// web clips ask. A locked or hidden app needs Face ID first, and hidden
    /// apps aren't found while Strict Hiding is on.
    func launchAppWithBundleId(bundleId: String, container: String?, urlStr: String? = nil, forceJIT: Bool? = nil) async {
        if bundleId.isEmpty {
            return
        }
        var appFound = sharedModel.apps.first { $0.appInfo.relativeBundlePath == bundleId }
        var isFoundAppLocked = appFound?.appInfo.isLocked ?? false
        if appFound == nil && !LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding") {
            appFound = sharedModel.hiddenApps.first { $0.appInfo.relativeBundlePath == bundleId }
            isFoundAppLocked = appFound != nil
        }

        if isFoundAppLocked && !sharedModel.isHiddenAppUnlocked {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return
                }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        guard let appFound else {
            errorMessage = "lc.appList.appNotFoundError".loc
            return
        }

        do {
            try await appFound.runApp(multitask: nil, containerFolderName: container, urlStr: urlStr, forceJIT: forceJIT)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens a URL the way iOS would: an `itms-services` link installs its app,
    /// another app's URL scheme launches the installed app that declares it
    /// (after Face ID, when it is locked), and a web page opens in the built-in
    /// browser. A URL without a scheme is taken as https.
    func openWebView(urlString: String) async {
        guard var components = URLComponents(string: urlString), components.url != nil else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }
        if components.scheme?.isEmpty ?? true {
            components.scheme = "https"
        }
        guard let url = components.url, let scheme = components.scheme else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }

        if scheme.lowercased() == "itms-services" {
            await installFromPlist(urlStr: urlString)
            return
        }

        if scheme != "https" && scheme != "http" {
            var appListsToConsider = [sharedModel.apps]
            if sharedModel.isHiddenAppUnlocked || !LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding") {
                appListsToConsider.append(sharedModel.hiddenApps)
            }
            let appToLaunch = appListsToConsider.joined().first { app in
                let schemes = app.appInfo.urlSchemes().map { Array($0) } ?? []
                return schemes.contains { $0 as? String == scheme }
            }
            guard let appToLaunch else {
                errorMessage = "lc.appList.schemeCannotOpenError %@".localizeWithFormat(scheme)
                return
            }

            if appToLaunch.appInfo.isLocked && !sharedModel.isHiddenAppUnlocked {
                do {
                    guard try await LCUtils.authenticateUser() else {
                        return
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }

            do {
                try await appToLaunch.runApp(urlStr: url.absoluteString)
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        webPageURL = url
        if isShowingWebPage {
            // Close the browser and open it again on the new page.
            isShowingWebPage = false
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                isShowingWebPage = true
            }
        } else {
            isShowingWebPage = true
        }
    }
}

extension AppLaunchCoordinator: LCAppModelDelegate {
    func closeNavigationView() {
        appSettingsCloseRequests += 1
    }

    /// Moves an app between the Home Screen and the hidden apps after it was
    /// hidden or shown. A hidden app's URL schemes stop counting as zContainer's,
    /// unless an app on the Home Screen declares them too.
    func changeAppVisibility(app: LCAppModel) {
        if app.appInfo.isHidden {
            sharedModel.apps.removeAll { $0 == app }
            if !sharedModel.hiddenApps.contains(app) {
                sharedModel.hiddenApps.append(app)
            }
        } else {
            sharedModel.hiddenApps.removeAll { $0 == app }
            if !sharedModel.apps.contains(app) {
                sharedModel.apps.append(app)
            }
        }
        refreshGuestURLSchemes()
    }

    func jitLaunch(appName: String, classicMode: UInt) async {
        await jitLaunch(withScript: "", appName: appName, classicMode: classicMode)
    }

    /// Asks the JIT enabler set in Settings to attach to the app, shows its log
    /// while it works, and launches the app the classic way when the person
    /// taps Launch Now. Cancel stops waiting and forgets the app to launch.
    func jitLaunch(withScript script: String, appName: String, classicMode: UInt) async {
        jitLog = ""
        let enableJITTask = Task {
            _ = await LCUtils.askForJIT(withScript: script, appName: appName, classicMode: classicMode) { message in
                Task { @MainActor in
                    self.jitLog += "\(message)\n"
                }
            }
        }
        sharedModel.isJITModalOpen = true
        let shouldLaunch = await jitPrompt.ask() ?? false
        sharedModel.isJITModalOpen = false
        guard shouldLaunch else {
            UserDefaults.standard.removeObject(forKey: "selected")
            enableJITTask.cancel()
            return
        }
        LCSharedUtils.launchToGuestApp(withClassicMode: classicMode)
    }

    /// Asks the JIT enabler to attach to an app already running in a
    /// multitasking window, by its process ID: Zeus, or StikDebug or StosDebug,
    /// either installed on the iPhone or inside zContainer as a shared app.
    func jitLaunch(withPID pid: Int, withScript script: String?, appName: String) async {
        let jitEnabler = JITEnablerType.current
        if jitEnabler == .Zeus {
            if !(await LCUtils.askZeusForJIT(withScript: script, pid: pid)) {
                errorMessage = LCUtils.zeusMissingForJIT
            }
            return
        }
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let encodedData = script?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        if jitEnabler == .StosDebug || jitEnabler == .StosDebugLC {
            let encoded = encodedData.map { "&script=\($0)" } ?? ""
            if jitEnabler == .StosDebugLC {
                guard hasSharedApp(withScheme: "stosdebug") else {
                    errorMessage = "StosDebug is not found. Please install it first and switch it to shared app."
                    return
                }
                if let url = URL(string: "stosdebug://enableJIT?bundleId=\(bundleIdentifier)&appName=\(appName)&pid=\(pid)&relaunchApp=false& forcePID=true\(encoded)") {
                    Task { await openWebView(urlString: url.absoluteString) }
                }
            } else if let url = URL(string: "stosdebug://enableJIT?bundleId=\(bundleIdentifier)&appName=\(appName)&pid=\(pid)&forcePID=true\(encoded)") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }

        let encoded = encodedData.map { "&script-data=\($0)" } ?? ""
        guard let url = URL(string: "stikjit://enable-jit?bundle-id=\(bundleIdentifier)&pid=\(pid)\(encoded)") else {
            return
        }
        if jitEnabler == .StikJITLC {
            guard hasSharedApp(withScheme: "stikjit") else {
                errorMessage = "StikDebug is not found. Please install it first and switch it to shared app."
                return
            }
            Task { await openWebView(urlString: url.absoluteString) }
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func showRunWhenMultitaskAlert() async -> Bool? {
        await runWhenMultitaskPrompt.ask()
    }

    /// Whether an app inside zContainer declares the URL scheme and can run
    /// here: in a secondary zContainer, only shared apps can.
    private func hasSharedApp(withScheme scheme: String) -> Bool {
        sharedModel.apps.contains { app in
            app.appInfo.urlSchemes().contains(scheme) && (sharedModel.multiLCStatus != 2 || app.appInfo.isShared)
        }
    }
}

#import "LCSharedUtils.h"
#import "LCZeusCertificate.h"
#import "FoundationPrivate.h"
#import "UIKitPrivate.h"
#import "utils.h"
@import MachO;

extern NSUserDefaults *lcUserDefaults;
extern NSString *lcAppUrlScheme;
extern NSBundle *lcMainBundle;

NSString* FBSOpenApplicationOptionKeyActivateAsClassic = @"__ActivateAsClassic";
NSString* FBSOpenApplicationOptionKeyPayloadURL = @"__PayloadURL";

// The app group zContainer shares with Zeus, as the entitlements ask for it.
// Zeus assigns this name followed by "." and the team when it signs zContainer,
// and SideStore, AltStore and Impactor append the team the same way.
static NSString * const LCZeusGroupBase = @"group.app.reiko.zeus";

@implementation LCSharedUtils

+ (NSString*) teamIdentifier {
    static NSString* ans = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if !TARGET_OS_SIMULATOR
        void* taskSelf = SecTaskCreateFromSelf(NULL);
        if(taskSelf) {
            CFErrorRef error = NULL;
            CFTypeRef cfans = SecTaskCopyValueForEntitlement(taskSelf, CFSTR("com.apple.developer.team-identifier"), &error);
            if(cfans && CFGetTypeID(cfans) == CFStringGetTypeID()) {
                ans = (__bridge_transfer NSString*)cfans;
            } else if(cfans) {
                CFRelease(cfans);
            }
            if(error) {
                CFRelease(error);
            }
            CFRelease(taskSelf);
        }
#endif
        if(!ans) {
            // the above seems not to work if the device is jailbroken by Palera1n, so we use the public api one as backup
            // https://stackoverflow.com/a/11841898
            NSString *tempAccountName = @"bundleSeedID";
            NSDictionary *query = @{
                (__bridge NSString *)kSecClass : (__bridge NSString *)kSecClassGenericPassword,
                (__bridge NSString *)kSecAttrAccount : tempAccountName,
                (__bridge NSString *)kSecAttrService : @"",
                (__bridge NSString *)kSecReturnAttributes: (__bridge NSNumber *)kCFBooleanTrue,
            };
            CFDictionaryRef result = nil;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == errSecItemNotFound)
                status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == errSecSuccess) {
                status = SecItemDelete((__bridge CFDictionaryRef)query); // remove temp item
                NSDictionary *dict = (__bridge_transfer NSDictionary *)result;
                NSString *accessGroup = dict[(__bridge NSString *)kSecAttrAccessGroup];
                NSArray *components = [accessGroup componentsSeparatedByString:@"."];
                NSString *bundleSeedID = [[components objectEnumerator] nextObject];
                ans = bundleSeedID;
            }
        }
    });
    return ans;
}

// The app groups in our own entitlements. Entries that aren't strings are left
// out; empty when the entitlement is missing or can't be read.
+ (NSArray<NSString *> *)entitledAppGroups {
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    void* taskSelf = SecTaskCreateFromSelf(NULL);
    if(!taskSelf) {
        return groups;
    }
    CFErrorRef error = NULL;
    CFTypeRef value = SecTaskCopyValueForEntitlement(taskSelf, CFSTR("com.apple.security.application-groups"), &error);
    CFRelease(taskSelf);
    if(error) {
        CFRelease(error);
    }
    if(!value) {
        return groups;
    }
    if(CFGetTypeID(value) != CFArrayGetTypeID()) {
        CFRelease(value);
        return groups;
    }
    NSArray *entries = (__bridge_transfer NSArray *)value;
    for(id entry in entries) {
        if([entry isKindOfClass:NSString.class] && [entry length] > 0) {
            [groups addObject:entry];
        }
    }
    return groups;
}

+ (NSString *)appGroupID {
    static dispatch_once_t once;
    // Without an app group, the shared defaults are the suite of this name, kept
    // in the app's own preferences. LiveContainer has always used it, so an
    // install updated in place keeps its settings and certificate.
    static NSString *appGroupID = @"Unknown";
    dispatch_once(&once, ^{
        // The app group comes from our own entitlements, which ask for
        // LCZeusGroupBase: the installer assigns that name with the team added,
        // and may assign other groups too. The group shared with Zeus comes
        // first, then the one remembered when a certificate was imported
        // (LCAppGroupID), then any group the app has. A group only counts when
        // the system gives its folder, which it does for entitled groups alone.
        NSArray<NSString *> *entitled = [self entitledAppGroups];
        NSString *zeusPrefix = [LCZeusGroupBase stringByAppendingString:@"."];
        NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
        NSString *team = self.teamIdentifier;
        if(team.length > 0) {
            [candidates addObject:[zeusPrefix stringByAppendingString:team]];
        }
        for(NSString *group in entitled) {
            if([group hasPrefix:zeusPrefix]) {
                [candidates addObject:group];
            }
        }
        id cached = [lcUserDefaults objectForKey:@"LCAppGroupID"];
        if([cached isKindOfClass:NSString.class] && [cached length] > 0) {
            [candidates addObject:cached];
        }
        if(entitled.firstObject) {
            [candidates addObject:entitled.firstObject];
        }
        for(NSString *candidate in candidates) {
            if([candidate isEqualToString:@"Unknown"]) {
                continue;
            }
            if([NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:candidate]) {
                appGroupID = candidate;
                return;
            }
        }
    });
    return appGroupID;
}

+ (NSURL*) appGroupPath {
    static NSURL *appGroupPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appGroupPath = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:[LCSharedUtils appGroupID]];
    });
    return appGroupPath;
}

+ (BOOL)hasAppGroup {
    return self.appGroupPath != nil;
}

+ (BOOL)sharesZeusGroup {
    return self.hasAppGroup && [self.appGroupID hasPrefix:[LCZeusGroupBase stringByAppendingString:@"."]];
}

// One preferences domain as it is stored. Unlike NSUserDefaults, it leaves out
// the app's own and the global defaults. Empty when the domain holds nothing.
+ (NSDictionary<NSString *, id> *)preferencesInDomain:(NSString *)domain {
    CFDictionaryRef values = CFPreferencesCopyMultiple(NULL, (__bridge CFStringRef)domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if(!values) {
        return @{};
    }
    if(CFGetTypeID(values) != CFDictionaryGetTypeID()) {
        CFRelease(values);
        return @{};
    }
    return (__bridge_transfer NSDictionary *)values;
}

// Apps inside kept their app groups in Documents/Data/AppGroup while zContainer
// had none of its own; with one, NSFileManager+GuestHooks looks for them in the
// group's LiveContainer/Data/AppGroup. Each moves over once, unless the group
// already holds one of that name.
+ (void)moveGuestAppGroupsIntoAppGroup {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *documents = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
    NSString *from = [documents.path stringByAppendingPathComponent:@"Data/AppGroup"];
    NSString *to = [self.appGroupPath.path stringByAppendingPathComponent:@"LiveContainer/Data/AppGroup"];
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:from error:nil];
    if(names.count == 0 || ![fm createDirectoryAtPath:to withIntermediateDirectories:YES attributes:nil error:nil]) {
        return;
    }
    for(NSString *name in names) {
        NSString *destination = [to stringByAppendingPathComponent:name];
        if([fm fileExistsAtPath:destination]) {
            continue;
        }
        NSError *error = nil;
        if(![fm moveItemAtPath:[from stringByAppendingPathComponent:name] toPath:destination error:&error]) {
            NSLog(@"[LC] Couldn't move the app group %@ into the shared one: %@", name, error.localizedDescription);
        }
    }
}

+ (void)migrateSharedDefaultsIfNeeded {
    NSString *group = self.appGroupID;
    if(!self.hasAppGroup || [group isEqualToString:@"Unknown"]) {
        return;
    }
    NSUserDefaults *standard = lcUserDefaults ?: NSUserDefaults.standardUserDefaults;
    NSString *migratedTo = [standard stringForKey:@"ZCSharedDefaultsMigratedTo"];
    if([migratedTo isEqualToString:group]) {
        return;
    }
    NSUserDefaults *shared = NSUserDefaults.lcSharedDefaults;
    if(!shared) {
        return;
    }
    NSDictionary<NSString *, id> *unknown = [self preferencesInDomain:@"Unknown"];
    NSDictionary<NSString *, id> *current = [self preferencesInDomain:group];

    // The certificate and what is known about it only make sense together, so
    // they are copied as one set, and only into a group that holds none.
    NSArray<NSString *> *certificateKeys = LCZeusCertificate.certificateKeys;
    // Left behind, with the Launch App shortcut's requests (LCLaunchExtension*):
    // the page to come back to after an app, and caches that are made again.
    NSSet<NSString *> *skipped = [NSSet setWithArray:@[
        @"ZCHomeScreenPage", @"symbolOffsetCache", @"LCLastIOSBuildVersion", @"LCGuestURLSchemes",
    ]];

    NSUInteger copied = 0;
    if(unknown[@"LCCertificateData"] && !current[@"LCCertificateData"]) {
        for(NSString *key in certificateKeys) {
            id value = unknown[key];
            if(value) {
                [shared setObject:value forKey:key];
                copied++;
            } else {
                [shared removeObjectForKey:key];
            }
        }
    }
    for(NSString *key in unknown) {
        if(![key isKindOfClass:NSString.class] || [certificateKeys containsObject:key] ||
           [skipped containsObject:key] || [key hasPrefix:@"LCLaunchExtension"] || current[key]) {
            continue;
        }
        [shared setObject:unknown[key] forKey:key];
        copied++;
    }
    // Only the first group zContainer has takes in the app groups it kept
    // without one.
    if(!migratedTo) {
        [self moveGuestAppGroupsIntoAppGroup];
    }
    // The "Unknown" suite stays as it is, for a build that runs without the
    // group again.
    [standard setObject:group forKey:@"ZCSharedDefaultsMigratedTo"];
    NSLog(@"[LC] Copied %lu settings from the Unknown suite into %@", (unsigned long)copied, group);
}

+ (NSString *)certificatePassword {
    NSUserDefaults* nud = NSUserDefaults.lcSharedDefaults ?: NSUserDefaults.standardUserDefaults;
    return [nud objectForKey:@"LCCertificatePassword"];
}

+ (BOOL)launchToGuestAppWithClassicMode:(NSUInteger)classicMode {
    void (^completionHandler)(BOOL) = ^(BOOL success) {
        // syscall(SYS_ptrace, PT_DENY_ATTACH, 0, 0, 0);
#if defined(__arm64__)
        __asm__ __volatile__ (
                              "mov x0, #31\n"
                              "mov x16, #26\n"
                              "svc #0x80"
                              );
#endif
        raise(SIGKILL);
    };
    
    if (!self.certificatePassword) {
        NSString *urlScheme = nil;
        NSString *tsPath = [NSString stringWithFormat:@"%@/../_TrollStore", NSBundle.mainBundle.bundlePath];
        if (!access(tsPath.UTF8String, F_OK)) {
            urlScheme = @"apple-magnifier://enable-jit?bundle-id=%@";
        }
        
        if(urlScheme) {
            NSURL *launchURL = [NSURL URLWithString:[NSString stringWithFormat:urlScheme, NSBundle.mainBundle.bundleIdentifier]];
            UIApplication *application = [NSClassFromString(@"UIApplication") sharedApplication];
            [application openURL:launchURL options:@{} completionHandler:completionHandler];
            return YES;
        }
    }

    int tries = 2;
    _LSOpenConfiguration *configuration = [[PrivClass(_LSOpenConfiguration) alloc] init];
    if(classicMode) {
        NSMutableDictionary* dict = [NSMutableDictionary new];
        dict[FBSOpenApplicationOptionKeyActivateAsClassic] = @(classicMode);
        configuration.frontBoardOptions = dict;
    }
    LSApplicationWorkspace* workspace = [PrivClass(LSApplicationWorkspace) defaultWorkspace];
    
    for (int i = 0; i < tries; i++) {
        [workspace openApplicationWithBundleIdentifier:NSUserDefaults.lcMainBundle.bundleIdentifier
                                         configuration:configuration
                                     completionHandler:^(BOOL success, NSError* error) {
            NSLog(@"success=%d error=%@", success, error);
            completionHandler(success);
        }];
    }
    return YES;
}

+ (BOOL)launchToGuestAppWithURL:(NSURL *)url {
    NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if(![components.host isEqualToString:@"livecontainer-launch"]) return NO;

    NSString* launchBundleId = nil;
    NSString* openUrl = nil;
    NSString* containerFolderName = nil;
    NSString* jit = nil;
    for (NSURLQueryItem* queryItem in components.queryItems) {
        if ([queryItem.name isEqualToString:@"bundle-name"]) {
            launchBundleId = queryItem.value;
        } else if ([queryItem.name isEqualToString:@"open-url"]){
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:queryItem.value options:0];
            openUrl = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
        } else if ([queryItem.name isEqualToString:@"container-folder-name"]) {
            containerFolderName = queryItem.value;
        } else if ([queryItem.name isEqualToString:@"jit"]) {
            jit = queryItem.value;
        }
    }
    if(launchBundleId) {
        if (openUrl) {
            [lcUserDefaults setObject:openUrl forKey:@"launchAppUrlScheme"];
        }
        
        // Attempt to restart LiveContainer with the selected guest app
        [lcUserDefaults setObject:launchBundleId forKey:@"selected"];
        [lcUserDefaults setObject:containerFolderName forKey:@"selectedContainer"];
        bool isSharedApp = false;
        NSBundle *appBundle = [self findBundleWithBundleId:launchBundleId isSharedAppOut:&isSharedApp];
        NSDictionary *appInfo = [NSDictionary dictionaryWithContentsOfFile:
            [appBundle.bundlePath stringByAppendingPathComponent:@"LCAppInfo.plist"]];
        NSUInteger classicMode = [appInfo[@"classicMode"] boolValue]
            ? [appInfo[@"LCClassicModeCache"][@"defaultClassicMode"] unsignedIntegerValue]
            : 0;
        // The app opens with JIT when it always does, or when the link says
        // so with jit=true, as an icon Add to Home Screen made can; jit=false
        // opens it without.
        BOOL needsJIT = [appInfo[@"isJITNeeded"] boolValue] || [appInfo[@"is32bit"] boolValue];
        if ([jit isEqualToString:@"true"]) {
            needsJIT = YES;
        } else if ([jit isEqualToString:@"false"]) {
            needsJIT = NO;
        }
        if (needsJIT && [self askZeusForJITWithClassicMode:classicMode]) {
            return YES;
        }
        return [self launchToGuestAppWithClassicMode:classicMode];
    }
    
    return NO;
}

/// Asks Zeus for JIT for the app selected to launch, when Zeus is the tool set
/// to enable JIT, as it is unless Settings > Advanced > JIT names another:
/// Zeus relaunches zContainer with the debugger attached and stays with it,
/// answering what the app asks for as it runs, and zContainer then opens the
/// app, as Open with JIT does from zContainer's Home Screen. Zeus needs no
/// script for that, so none goes with the link. When Zeus can't be opened,
/// zContainer opens the app without JIT instead. Returns NO, asking for
/// nothing, when another tool is set.
+ (BOOL)askZeusForJITWithClassicMode:(NSUInteger)classicMode {
    // JITEnablerType.Zeus, saved under LCJITEnablerType once the person picks a tool.
    NSNumber* jitEnabler = [NSUserDefaults.lcSharedDefaults objectForKey:@"LCJITEnablerType"];
    if (jitEnabler && jitEnabler.integerValue != 7) {
        return NO;
    }
    NSURLComponents* zeusLink = [NSURLComponents new];
    zeusLink.scheme = @"zeus";
    zeusLink.host = @"enable-jit";
    zeusLink.queryItems = @[[NSURLQueryItem queryItemWithName:@"bundle-id" value:NSUserDefaults.lcMainBundle.bundleIdentifier]];
    UIApplication *application = [NSClassFromString(@"UIApplication") sharedApplication];
    [application openURL:zeusLink.URL options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            [self launchToGuestAppWithClassicMode:classicMode];
        }
    }];
    return YES;
}

+ (void)setWebPageUrlForNextLaunch:(NSString*) urlString {
    [lcUserDefaults setObject:urlString forKey:@"webPageToOpen"];
}

+ (NSURL*)containerLockPath {
    static dispatch_once_t once;
    static NSURL *infoPath;
    
    dispatch_once(&once, ^{
        infoPath = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer/containerLock.plist"];
    });
    return infoPath;
}

+ (BOOL)isLCSchemeInUse:(NSString*)lc {
    NSURL* infoPath = [self containerLockPath];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        return NO;
    }
    
    NSNumber* num57 = info[lc];
    if(![num57 isKindOfClass:NSNumber.class]) {
        return NO;
    }
    
    uint64_t val57 = [num57 longLongValue];
    audit_token_t token;
    token.val[5] = val57 >> 32;
    token.val[7] = val57 & 0xffffffff;
    
    errno = 0;
    csops_audittoken(token.val[5], 0, NULL, 0, &token);
    return errno != ESRCH;
}

+ (NSString*)getContainerUsingLCSchemeWithFolderName:(NSString*)folderName {
    NSURL* infoPath = [self containerLockPath];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        return nil;
    }
    
    NSDictionary* appUsageInfo = info[folderName];
    if (!appUsageInfo) {
        return nil;
    }
    uint64_t val57 = [appUsageInfo[@"auditToken57"] longLongValue];
    audit_token_t token;
    token.val[5] = val57 >> 32;
    token.val[7] = val57 & 0xffffffff;
    
    errno = 0;
    csops_audittoken(token.val[5], 0, NULL, 0, &token);
    return errno==ESRCH ? nil : appUsageInfo[@"runningLC"];
}

// lc can be something like livecontainer or livecontainer2.liveprocess, such that one LC can jump to another LC hosting the multitask app when user presses run while it's running
+ (void)setContainerUsingByLC:(NSString*)lc folderName:(NSString*)folderName auditToken:(uint64_t)val57 {
    NSURL* infoPath = [self containerLockPath];
    
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        info = [NSMutableDictionary new];
    }
    
    if(val57 == 0) {
        audit_token_t token;
        mach_msg_type_number_t size = TASK_AUDIT_TOKEN_COUNT;
        
        kern_return_t kr = task_info(mach_task_self(), TASK_AUDIT_TOKEN, (task_info_t)&token, &size);
        if (kr != KERN_SUCCESS) {
            NSLog(@"Error getting task audit_token");
        }
        val57 = token.val[7] | ((uint64_t)token.val[5] << 32);
    }
    info[folderName] = @{
        @"runningLC": lc,
        @"auditToken57": @(val57)
    };
    
    info[lc] = @(val57);

    [info writeBinToFile:infoPath.path atomically:YES];
}

// move app data to private folder to prevent 0xdead10cc https://forums.developer.apple.com/forums/thread/126438
// This method is here for backward compatability, 0xdead10cc is already resolved.
+ (void)moveSharedAppFolderBack {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *libraryPathUrl = [fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask]
        .lastObject;
    NSURL *docPathUrl = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask]
        .lastObject;
    NSURL *appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
    
    NSError *error;
    NSString *sharedAppDataFolderPath = [libraryPathUrl.path stringByAppendingPathComponent:@"SharedDocuments"];
    if(![fm fileExistsAtPath:sharedAppDataFolderPath]){
        return;
    }
    // move all apps in shared folder back
    NSArray<NSString *> * sharedDataFoldersToMove = [fm contentsOfDirectoryAtPath:sharedAppDataFolderPath error:&error];
    
    // something went wrong with app group
    if(!appGroupFolder && sharedDataFoldersToMove.count > 0) {
        [lcUserDefaults setObject:@"zContainer was unable to move the data of shared app back because zContainer cannot access app group. Please check JITLess diagnose page in zContainer settings for more information." forKey:@"error"];
        return;
    }
    
    for(int i = 0; i < [sharedDataFoldersToMove count]; ++i) {
        NSString* destPath = [appGroupFolder.path stringByAppendingPathComponent:[NSString stringWithFormat:@"Data/Application/%@", sharedDataFoldersToMove[i]]];
        if([fm fileExistsAtPath:destPath]) {
            [fm
             moveItemAtPath:[sharedAppDataFolderPath stringByAppendingPathComponent:sharedDataFoldersToMove[i]]
             toPath:[docPathUrl.path stringByAppendingPathComponent:[NSString stringWithFormat:@"FOLDER_EXISTS_AT_APP_GROUP_%@", sharedDataFoldersToMove[i]]]
             error:&error
            ];
            
        } else {
            [fm
             moveItemAtPath:[sharedAppDataFolderPath stringByAppendingPathComponent:sharedDataFoldersToMove[i]]
             toPath:destPath
             error:&error
            ];
        }
    }
    
}

+ (NSBundle*)findBundleWithBundleId:(NSString*)bundleId isSharedAppOut:(bool*)isSharedAppOut {
    NSString *docPath = [NSString stringWithFormat:@"%s/Documents", getenv("LC_HOME_PATH")];
    
    NSURL *appGroupFolder = nil;
    
    NSString *bundlePath = [NSString stringWithFormat:@"%@/Applications/%@", docPath, bundleId];
    NSBundle *appBundle;
    if([NSFileManager.defaultManager fileExistsAtPath:bundlePath]) {
        appBundle = [[NSBundle alloc] initWithPath:bundlePath];
    }

    // not found locally, let's look for the app in shared folder
    if (!appBundle) {
        appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
        
        bundlePath = [NSString stringWithFormat:@"%@/Applications/%@", appGroupFolder.path, bundleId];
        if([NSFileManager.defaultManager fileExistsAtPath:bundlePath]) {
            appBundle = [[NSBundle alloc] initWithPath:bundlePath];
        }
        if(appBundle) {
            *isSharedAppOut = true;
        }
    } else {
        *isSharedAppOut = false;
    }
    return appBundle;
}

// This method is here for backward compatability, preferences is direcrly saved to app's preference folder.
+ (void)dumpPreferenceToPath:(NSString*)plistLocationTo dataUUID:(NSString*)dataUUID {
    NSFileManager* fm = [[NSFileManager alloc] init];
    NSError* error1;
    
    NSDictionary* preferences = [lcUserDefaults objectForKey:dataUUID];
    if(!preferences) {
        return;
    }
    
    [fm createDirectoryAtPath:plistLocationTo withIntermediateDirectories:YES attributes:@{} error:&error1];
    for(NSString* identifier in preferences) {
        NSDictionary* preference = preferences[identifier];
        NSString *itemPath = [plistLocationTo stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", identifier]];
        if([preference count] == 0) {
            // Attempt to delete the file
            [fm removeItemAtPath:itemPath error:&error1];
            continue;
        }
        [preference writeToFile:itemPath atomically:YES];
    }
    [lcUserDefaults removeObjectForKey:dataUUID];
}

+ (NSString*)findDefaultContainerWithBundleId:(NSString*)bundleId {
    // find app's default container
    NSURL* appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
    
    NSString* bundleInfoPath = [NSString stringWithFormat:@"%@/Applications/%@/LCAppInfo.plist", appGroupFolder.path, bundleId];
    NSDictionary* infoDict = [NSDictionary dictionaryWithContentsOfFile:bundleInfoPath];
    return infoDict[@"LCDataUUID"];
}

// The first URL scheme in the app's own Info.plist, read from the host app when
// this runs in one of its extensions (LiveProcess, the share and launch
// extensions), which sit two folders down in PlugIns. It is "zcontainer" unless
// a build sets another (ZC_URL_SCHEME in the Linux build), so a test build can
// sit next to zContainer without taking its links. Every link zContainer makes
// for itself, or checks as its own, uses this rather than a literal scheme.
+ (NSString *)hostAppUrlScheme {
    static NSString *scheme = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // lcMainBundle keeps the app's bundle after a guest app takes over
        // NSBundle.mainBundle; extensions that don't run LiveContainerMain leave it nil.
        NSBundle *bundle = lcMainBundle ?: NSBundle.mainBundle;
        if([bundle.bundlePath.pathExtension isEqualToString:@"appex"]) {
            NSURL *appURL = bundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent;
            bundle = [NSBundle bundleWithURL:appURL] ?: bundle;
        }
        id urlTypes = bundle.infoDictionary[@"CFBundleURLTypes"];
        if([urlTypes isKindOfClass:NSArray.class] && [urlTypes count] > 0 && [urlTypes[0] isKindOfClass:NSDictionary.class]) {
            id schemes = urlTypes[0][@"CFBundleURLSchemes"];
            if([schemes isKindOfClass:NSArray.class] && [schemes count] > 0 && [schemes[0] isKindOfClass:NSString.class]) {
                scheme = schemes[0];
            }
        }
        if(scheme.length == 0) {
            scheme = @"zcontainer";
        }
    });
    return scheme;
}

+ (NSArray<NSString*>*)lcUnorderedUrlSchemes {
    NSArray<NSString *> *defaultSchemes = @[self.hostAppUrlScheme];
    return defaultSchemes;
}

+ (NSArray<NSString*>*)lcUrlSchemes {
    NSArray<NSString *> *defaultSchemes = [self lcUnorderedUrlSchemes];
    NSSet<NSString *> *allowedSchemes = [NSSet setWithArray:defaultSchemes];
    NSMutableArray<NSString *> *result = [NSMutableArray array];

    id savedValue = [NSUserDefaults.lcSharedDefaults objectForKey:@"LCMultiLaunchPriority"];
    if([savedValue isKindOfClass:NSArray.class]) {
        for(id value in (NSArray *)savedValue) {
            if(![value isKindOfClass:NSString.class]) {
                continue;
            }

            NSString *scheme = [(NSString *)value lowercaseString];
            if(![allowedSchemes containsObject:scheme] || [result containsObject:scheme]) {
                continue;
            }

            [result addObject:scheme];
        }
    }

    for(NSString *scheme in defaultSchemes) {
        if(![result containsObject:scheme]) {
            [result addObject:scheme];
        }
    }

    return result;
}
@end

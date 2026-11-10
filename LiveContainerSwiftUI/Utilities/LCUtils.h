#import <Foundation/Foundation.h>
#import "LCMachOUtils.h"
#import "utils.h"
@import UIKit;

void refreshFile(NSString* execPath);
int dyld_get_program_sdk_version(void);
uint32_t dyld_get_sdk_version(const struct mach_header* mh);

@interface UIDevice(private)
@property(readonly) NSString* buildVersion;
@end

@interface LCUtils : NSObject

+ (void)validateJITLessSetupWithCompletionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
+ (NSData *)certificateData;
+ (void)launchMultitaskGuestApp:(NSString *)displayName completionHandler:(void (^)(NSNumber *pid, NSError *error))completionHandler API_AVAILABLE(ios(16.0));


+ (NSProgress *)signAppBundleWithZSign:(NSURL *)path completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
+ (NSProgress *)signFilesWithZSignWithURLs:(NSArray<NSURL*>*)urls completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
+ (NSString*)getCertTeamIdWithKeyData:(NSData*)keyData password:(NSString*)password;
+ (int)validateCertificateWithCompletionHandler:(void(^)(int status, NSDate *expirationDate, NSString *organizationalUnitName, NSString *error))completionHandler;

+ (BOOL)isTXMScriptRequired;
+ (NSString *)base64EncodedUniversalJITScript;

+ (NSString *)appUrlScheme;
+ (NSString *)getVersionInfo;
+ (NSString *)liveProcessBundleIdentifier;
+ (NSData*)bookmarkForURL:(NSURL*) url;
@end

@interface LCP12CertHelper : NSObject

- (instancetype)initWithP12Data:(NSData*)p12Data password:(NSString*)password error:(NSError**)error;
- (NSDate*)getNotValidityNotAfterWithError:(NSError**)error;
- (NSString*)getOrgnizationUnitWithError:(NSError**)error;

@end

typedef NS_ENUM(NSInteger, GeneratedIconStyle){
    Original = -1,
    Light = 0,
    Dark = 1
};

@interface UIImage(LiveContainer)
+ (instancetype)generateIconForBundleURL:(NSURL*)url style:(GeneratedIconStyle)style hasBorder:(BOOL)hasBorder;
/// One of the graphic icons the Settings app draws beside its rows, such as
/// com.apple.graphic-icon.gear for General, drawn by IconServices `size`
/// points square, or nil where the system has no such icon.
+ (instancetype)graphicIconOfType:(NSString *)type size:(CGFloat)size dark:(BOOL)dark;
@end
BOOL saveCGImage(CGImageRef image, NSURL *url);
CGImageRef loadCGImageFromURL(NSURL *url);
NSNumber *LCGetDefaultClassicMode(NSURL *appURL);

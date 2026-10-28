#import "FoundationPrivate.h"
#import "AppSceneViewController.h"

API_AVAILABLE(ios(16.0))
@interface DecoratedAppSceneViewController : UIViewController<AppSceneViewControllerDelegate>
@property(nonatomic) AppSceneViewController* appSceneVC;
@property(nonatomic) UIStackView *view;
@property(nonatomic) UINavigationBar *navigationBar;
@property(nonatomic) UINavigationItem *navigationItem;
@property(nonatomic) UIView *resizeHandle;
@property(nonatomic) UIView* contentView;

@property(nonatomic) BOOL isMaximized;
@property(nonatomic) CGFloat scaleRatio;
/// Which half of the screen the window is snapped to (an LCWindowSnapSlot),
/// or none while it floats.
@property(nonatomic, readonly) NSInteger snapSlot;
/// Whether the window is tucked into the side of the screen, as macOS tucks
/// away Picture in Picture, with a tab at the edge that brings it back.
@property(nonatomic, readonly) BOOL isStashed;
- (instancetype)initWindowName:(NSString*)windowName bundleId:(NSString*)bundleId dataUUID:(NSString*)dataUUID rootVC:(UIViewController*)rootVC;
/// Closes the window, ending its app, as its red dot does.
- (void)closeWindow;
- (void)minimizeWindow;
/// Brings a minimized window back out of its app's icon in the multitask
/// dock, the way it went in.
- (void)restoreFromDock;
- (void)minimizeWindowPiP;
- (void)unminimizeWindowPiP;
- (void)updateVerticalConstraints;
/// Shows the floating window controls of a full-screen window for a few
/// seconds; does nothing to a window that isn't full screen.
- (void)revealWindowControls;
/// Shows them for a status bar tap on its leading half, and says whether it
/// did, so the tap doesn't also scroll the app to the top.
- (BOOL)revealWindowControlsForStatusBarTap:(UIAction *)action;
/// Called by LCWindowSnapManager: the window moves into a half of the
/// screen, at `frame`.
- (void)didSnapToSlot:(NSInteger)slot frame:(CGRect)frame;
/// Called by LCWindowSnapManager: the window left its half and floats
/// again, back where it was before it snapped when `restoresFrame`.
- (void)didLeaveSnapRestoringFrame:(BOOL)restoresFrame;
/// Brings a tucked-away window back onto the screen, against the side it
/// was tucked into.
- (void)unstashAnimated:(BOOL)animated;
/// Puts a tucked-away window against its side again, as when the screen
/// rotates.
- (void)restash;
@property(nonatomic, copy) void (^pidAvailableHandler)(NSNumber *pid, NSError *error);
@end


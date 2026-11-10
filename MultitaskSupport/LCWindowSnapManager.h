//
//  LCWindowSnapManager.h
//  LiveContainer
//

#import <UIKit/UIKit.h>

@class DecoratedAppSceneViewController;

/// The halves of the screen a window snaps to. They split the screen across
/// its long side: top and bottom in portrait, left and right in landscape.
typedef NS_ENUM(NSInteger, LCWindowSnapSlot) {
    LCWindowSnapSlotNone = 0,
    /// The top half, or the left half in landscape.
    LCWindowSnapSlotFirst = 1,
    /// The bottom half, or the right half in landscape.
    LCWindowSnapSlotSecond = 2,
};

/// Posted as an iPhone's split screen starts waiting for its second app,
/// gets one, or ends.
extern NSNotificationName const LCPhoneSplitDidChangeNotification;

/// The radius of the corners where the two halves of an iPhone's split
/// screen meet the divider.
extern const CGFloat LCPhoneSplitCornerRadius;

/// Snaps windows to halves of the screen, as Windows does: a window dragged
/// to the top or bottom edge shows where it would go, and fills that half
/// when let go. With a window in each half, a divider between them slides to
/// share the screen differently.
///
/// On iPhone, where apps fill the screen rather than float in windows, it
/// runs the split screen other phones have instead: two apps edge to edge,
/// one above the other (side by side in landscape), over black, with a
/// divider between them that slides, closes the app beyond it when it's let
/// go near the end of the screen, and swaps them on a double tap.
API_AVAILABLE(ios(16.0))
@interface LCWindowSnapManager : NSObject

@property(class, nonatomic, readonly) LCWindowSnapManager *shared;

/// The half a window dragged with the finger at `location` would snap to,
/// or none when the finger isn't at an edge.
- (LCWindowSnapSlot)slotForFingerLocation:(CGPoint)location inView:(UIView *)hostView;

/// Shows where a dragged window would go, under it, while the finger is at
/// an edge, and hides that again when it moves away.
- (void)showPreviewForWindow:(DecoratedAppSceneViewController *)window fingerLocation:(CGPoint)location;

/// Hides where a dragged window would go.
- (void)hidePreview;

/// Snaps a window into a half. A window already there floats again, back
/// where it was before it snapped.
- (void)snapWindow:(DecoratedAppSceneViewController *)window toSlot:(LCWindowSnapSlot)slot;

/// Takes a window out of its half. It stays where it is until it moves.
- (void)releaseWindow:(DecoratedAppSceneViewController *)window;

/// Where a snapped window goes now, or CGRectNull for one that isn't snapped.
- (CGRect)frameForWindow:(DecoratedAppSceneViewController *)window;

/// Lays the snapped windows and the divider out again, as when the screen
/// rotates.
- (void)layoutInView:(UIView *)hostView;

/// Shows the divider only while a window shows in each half, as one is
/// minimized or comes back.
- (void)windowVisibilityDidChange;

/// Keeps the divider above the windows after one comes to the front.
- (void)keepDividerOnTopInView:(UIView *)hostView;

/// Whether the halves are stacked top and bottom in the view, as in
/// portrait, rather than side by side.
- (BOOL)stacksVerticallyInView:(UIView *)hostView;

#pragma mark iPhone split screen

/// Whether windows are laid out as on a phone: each app fills the screen,
/// or a half of the split screen. On iPhone.
@property(class, nonatomic, readonly) BOOL usesPhoneLayout;

/// Has the next window that opens, or the running app's window brought
/// forward, go into `slot` of the split screen, if one comes soon. The first
/// half starts a new split screen; the second goes beside the first.
- (void)requestPhoneSplitSlot:(LCWindowSnapSlot)slot;
/// Forgets a request no window took, as when the app didn't open.
- (void)cancelPhoneSplitRequest;
/// Puts `window` into the split screen when a request is waiting for it,
/// and says whether it did.
- (BOOL)claimPhoneSplitRequestForWindow:(DecoratedAppSceneViewController *)window;
/// Whether an app fills the first half while the second waits for one to
/// be picked.
@property(nonatomic, readonly) BOOL isAwaitingSecondPhoneSplitApp;
/// The container of the app in the first half, which the picker leaves out.
@property(nonatomic, readonly) NSString *firstPhoneSplitDataUUID;
/// Puts a full-screen window into the first half, to wait for a second
/// app, as its green button does.
- (void)startPhoneSplitWithWindow:(DecoratedAppSceneViewController *)window;
/// Ends a split screen still waiting for its second app: its app fills the
/// screen again.
- (void)cancelPhoneSplit;
/// Ends the split screen with `window` filling the screen, and the other
/// app in the dock, as `window`'s green button does.
- (void)makeFullScreenFromPhoneSplit:(DecoratedAppSceneViewController *)window;
/// Makes room beside the app that shows for an app added from the multitask
/// dock: an app filling the screen goes into the first half, and in a split
/// screen the second half takes the new app. Says whether an app shows to go
/// beside; with none, the new app fills the screen.
- (BOOL)prepareToAddPhoneSplitAppInView:(UIView *)hostView NS_SWIFT_NAME(prepareToAddPhoneSplitApp(in:));

@end

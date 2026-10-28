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

/// Snaps windows to halves of the screen, as Windows does: a window dragged
/// to the top or bottom edge shows where it would go, and fills that half
/// when let go. With a window in each half, a divider between them slides to
/// share the screen differently.
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

@end

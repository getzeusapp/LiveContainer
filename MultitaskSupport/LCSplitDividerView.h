//
//  LCSplitDividerView.h
//  LiveContainer
//

#import <UIKit/UIKit.h>

@class LCSplitDividerView;

/// Hears the divider move, to resize the windows on either side of it.
@protocol LCSplitDividerViewDelegate <NSObject>
/// The finger moved the divider by `delta` points along the split: down in
/// portrait, right in landscape.
- (void)splitDivider:(LCSplitDividerView *)divider didMoveBy:(CGFloat)delta;
/// The finger let go of the divider.
- (void)splitDividerDidEndMoving:(LCSplitDividerView *)divider;
/// VoiceOver asked to give the first window more room, or less.
- (void)splitDivider:(LCSplitDividerView *)divider adjustGrowingFirst:(BOOL)growsFirst;
@end

/// The divider between two snapped windows: a pill in the gap between them
/// that slides to share the screen differently. It takes touches all along
/// the gap, and a little into the windows around the pill, so it's easy to
/// grab without covering the windows' title bars.
@interface LCSplitDividerView : UIView
/// Whether the windows are stacked top and bottom, so the divider runs
/// across the screen. In landscape they sit side by side.
@property(nonatomic) BOOL stacksVertically;
/// The width of the gap between the windows, inside the divider's bounds.
@property(nonatomic) CGFloat gapWidth;
@property(nonatomic, weak) id<LCSplitDividerViewDelegate> delegate;
@end

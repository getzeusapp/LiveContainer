@import UIKit;
#import "LCHomeButtonEdge.h"

NS_ASSUME_NONNULL_BEGIN

// Where the Home button rests over a running app: against one edge of the
// screen, a fraction of the way along it. Keeping a fraction rather than a
// point leaves the button in the same spot when the screen rotates or changes
// size. The last place is saved in zContainer's own defaults, so it is the
// same in every app, as AssistiveTouch's is.
@interface LCHomeButtonPlacement : NSObject

// The edge the button rests against.
@property (nonatomic, readonly) LCHomeButtonEdge edge;
// How far along that edge the button rests, from 0 at its top or left end to
// 1 at its bottom or right end.
@property (nonatomic, readonly) CGFloat fraction;

// The place saved last, or nil before the button was ever moved.
+ (nullable instancetype)savedPlacement;

// The first place, before the button is moved. On an iPad it's halfway along
// the edge beside the iPad's own Home button, as iPads with one have it, which
// turns with the iPad: the bottom in portrait, the left or the right in
// landscape, and the top upside down. On an iPhone it's the right edge, a
// little below the middle, clear of the bars most apps have at the top and
// bottom.
+ (instancetype)firstPlacementForInterfaceOrientation:(UIInterfaceOrientation)orientation;

// The place on the edge nearest to `point`, for a button whose center moves
// within `area`. The sides win over the top and bottom unless the point is
// much closer to those, as with AssistiveTouch.
+ (instancetype)placementNearestToPoint:(CGPoint)point inArea:(CGRect)area;

// Where the button's center goes for this place, when its center moves
// within `area`.
- (CGPoint)centerInArea:(CGRect)area;

// Saves this place for the next time the button shows, in this app or another.
- (void)save;

@end

NS_ASSUME_NONNULL_END

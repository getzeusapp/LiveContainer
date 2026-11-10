#import "LCHomeButtonPlacement.h"
#import "../../LiveContainer/utils.h"

// Where the place is saved, in zContainer's own defaults.
static NSString * const LCHomeButtonPlacementKey = @"ZCHomeButtonPlacement";
// How many times closer to the top or bottom than to a side a point must be
// for the button to rest against the top or bottom.
static const CGFloat LCHomeButtonSidePreference = 3;
// The first place on an iPhone: how far down the right edge the button rests.
static const CGFloat LCHomeButtonFirstFraction = 0.62;

@implementation LCHomeButtonPlacement

- (instancetype)initWithEdge:(LCHomeButtonEdge)edge fraction:(CGFloat)fraction {
    self = [super init];
    if (self) {
        _edge = edge;
        _fraction = isfinite(fraction) ? MIN(MAX(fraction, 0), 1) : 0.5;
    }
    return self;
}

+ (instancetype)savedPlacement {
    NSDictionary *saved = [NSUserDefaults.lcUserDefaults dictionaryForKey:LCHomeButtonPlacementKey];
    NSNumber *edge = saved[@"edge"];
    NSNumber *fraction = saved[@"fraction"];
    if ([edge isKindOfClass:NSNumber.class] && [fraction isKindOfClass:NSNumber.class] &&
        edge.integerValue >= LCHomeButtonEdgeLeft && edge.integerValue <= LCHomeButtonEdgeBottom) {
        return [[self alloc] initWithEdge:edge.integerValue fraction:fraction.doubleValue];
    }
    return nil;
}

+ (instancetype)firstPlacementForInterfaceOrientation:(UIInterfaceOrientation)orientation {
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        return [[self alloc] initWithEdge:LCHomeButtonEdgeRight fraction:LCHomeButtonFirstFraction];
    }
    // In landscape left, as UIKit names it, the iPad's Home button is on the
    // left of the screen.
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            return [[self alloc] initWithEdge:LCHomeButtonEdgeLeft fraction:0.5];
        case UIInterfaceOrientationLandscapeRight:
            return [[self alloc] initWithEdge:LCHomeButtonEdgeRight fraction:0.5];
        case UIInterfaceOrientationPortraitUpsideDown:
            return [[self alloc] initWithEdge:LCHomeButtonEdgeTop fraction:0.5];
        default:
            return [[self alloc] initWithEdge:LCHomeButtonEdgeBottom fraction:0.5];
    }
}

+ (instancetype)placementNearestToPoint:(CGPoint)point inArea:(CGRect)area {
    CGFloat x = MIN(MAX(point.x, CGRectGetMinX(area)), CGRectGetMaxX(area));
    CGFloat y = MIN(MAX(point.y, CGRectGetMinY(area)), CGRectGetMaxY(area));
    CGFloat alongSide = CGRectGetHeight(area) > 0 ? (y - CGRectGetMinY(area)) / CGRectGetHeight(area) : 0.5;
    CGFloat alongTop = CGRectGetWidth(area) > 0 ? (x - CGRectGetMinX(area)) / CGRectGetWidth(area) : 0.5;

    CGFloat toLeft = x - CGRectGetMinX(area);
    CGFloat toRight = CGRectGetMaxX(area) - x;
    CGFloat toTop = (y - CGRectGetMinY(area)) * LCHomeButtonSidePreference;
    CGFloat toBottom = (CGRectGetMaxY(area) - y) * LCHomeButtonSidePreference;
    CGFloat nearest = MIN(MIN(toLeft, toRight), MIN(toTop, toBottom));

    if (nearest == toLeft) {
        return [[self alloc] initWithEdge:LCHomeButtonEdgeLeft fraction:alongSide];
    } else if (nearest == toRight) {
        return [[self alloc] initWithEdge:LCHomeButtonEdgeRight fraction:alongSide];
    } else if (nearest == toTop) {
        return [[self alloc] initWithEdge:LCHomeButtonEdgeTop fraction:alongTop];
    }
    return [[self alloc] initWithEdge:LCHomeButtonEdgeBottom fraction:alongTop];
}

- (CGPoint)centerInArea:(CGRect)area {
    CGFloat x = CGRectGetMinX(area) + CGRectGetWidth(area) * self.fraction;
    CGFloat y = CGRectGetMinY(area) + CGRectGetHeight(area) * self.fraction;
    switch (self.edge) {
        case LCHomeButtonEdgeLeft:
            return CGPointMake(CGRectGetMinX(area), y);
        case LCHomeButtonEdgeTop:
            return CGPointMake(x, CGRectGetMinY(area));
        case LCHomeButtonEdgeBottom:
            return CGPointMake(x, CGRectGetMaxY(area));
        case LCHomeButtonEdgeRight:
        default:
            return CGPointMake(CGRectGetMaxX(area), y);
    }
}

- (void)save {
    [NSUserDefaults.lcUserDefaults setObject:@{@"edge": @(self.edge), @"fraction": @(self.fraction)}
                                      forKey:LCHomeButtonPlacementKey];
}

@end

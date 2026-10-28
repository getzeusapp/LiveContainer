//
//  LCSplitDividerView.m
//  LiveContainer
//

#import "LCSplitDividerView.h"

/// The pill's length and thickness, as iPadOS draws Split View's.
static const CGFloat LCDividerPillLength = 56.0;
static const CGFloat LCDividerPillThickness = 5.0;
/// How far around the pill a touch still grabs it, into the windows.
static const CGFloat LCDividerPillSlopAlong = 44.0;
static const CGFloat LCDividerPillSlopAcross = 12.0;

@implementation LCSplitDividerView {
    UIView *_pill;
    BOOL _isMoving;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.backgroundColor = UIColor.clearColor;
    _gapWidth = 10.0;

    _pill = [[UIView alloc] init];
    _pill.userInteractionEnabled = NO;
    _pill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    // A shadow keeps the pill readable over a light wallpaper.
    _pill.layer.shadowColor = UIColor.blackColor.CGColor;
    _pill.layer.shadowOpacity = 0.35;
    _pill.layer.shadowRadius = 3.0;
    _pill.layer.shadowOffset = CGSizeZero;
    [self addSubview:_pill];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dividerPanned:)];
    pan.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:pan];

    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"Split";
    self.accessibilityTraits = UIAccessibilityTraitAdjustable;
    return self;
}

- (void)setStacksVertically:(BOOL)stacksVertically {
    _stacksVertically = stacksVertically;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat scale = _isMoving ? 1.2 : 1.0;
    CGSize size = self.stacksVertically
        ? CGSizeMake(LCDividerPillLength * scale, LCDividerPillThickness)
        : CGSizeMake(LCDividerPillThickness, LCDividerPillLength * scale);
    _pill.bounds = CGRectMake(0, 0, size.width, size.height);
    _pill.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _pill.layer.cornerRadius = LCDividerPillThickness / 2;
    _pill.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_pill.bounds cornerRadius:LCDividerPillThickness / 2].CGPath;
}

/// The gap between the windows, all along, and around the pill a little into
/// the windows, so the rest of their title bars stay theirs.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (![super pointInside:point withEvent:event]) {
        return NO;
    }
    CGRect gap = self.bounds;
    if (self.stacksVertically) {
        gap = CGRectInset(gap, 0, MAX(0, (gap.size.height - self.gapWidth) / 2));
    } else {
        gap = CGRectInset(gap, MAX(0, (gap.size.width - self.gapWidth) / 2), 0);
    }
    if (CGRectContainsPoint(gap, point)) {
        return YES;
    }
    CGRect aroundPill = self.stacksVertically
        ? CGRectInset(_pill.frame, -LCDividerPillSlopAlong, -LCDividerPillSlopAcross)
        : CGRectInset(_pill.frame, -LCDividerPillSlopAcross, -LCDividerPillSlopAlong);
    return CGRectContainsPoint(aroundPill, point);
}

- (void)dividerPanned:(UIPanGestureRecognizer *)pan {
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            [self setMoving:YES];
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint translation = [pan translationInView:self.superview];
            [pan setTranslation:CGPointZero inView:self.superview];
            [self.delegate splitDivider:self didMoveBy:self.stacksVertically ? translation.y : translation.x];
            break;
        }
        default:
            [self setMoving:NO];
            [self.delegate splitDividerDidEndMoving:self];
            break;
    }
}

/// The pill grows and turns fully white while it's held.
- (void)setMoving:(BOOL)moving {
    _isMoving = moving;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_pill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:moving ? 1.0 : 0.85];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)accessibilityIncrement {
    [self.delegate splitDivider:self adjustGrowingFirst:YES];
}

- (void)accessibilityDecrement {
    [self.delegate splitDivider:self adjustGrowingFirst:NO];
}

@end

//
//  LCWindowSnapManager.m
//  LiveContainer
//

#import "LCWindowSnapManager.h"
#import "LCSplitDividerView.h"
#import "DecoratedAppSceneViewController.h"

/// Space between a snapped window and the screen's edges, so its rounded
/// corners and shadow show.
static const CGFloat LCSnapMargin = 6.0;
/// The gap between two snapped windows, which the divider sits in.
static const CGFloat LCSnapGap = 10.0;
/// How far the divider's view reaches into the windows on either side, for
/// touches around its pill.
static const CGFloat LCSnapDividerOverlap = 12.0;
/// How close to an edge the finger has to come for a dragged window to snap
/// there. The bottom's reaches furthest, since a finger holding a tall
/// window's title bar can't get near the bottom edge.
static const CGFloat LCSnapTopZone = 44.0;
static const CGFloat LCSnapBottomZone = 110.0;
static const CGFloat LCSnapSideZone = 40.0;
/// The least room a snapped window gets along the split.
static const CGFloat LCSnapMinimumLength = 160.0;
/// The windows' corner radius, which the preview of where one goes shares.
static const CGFloat LCSnapPreviewCornerRadius = 22.0;
/// The shares of the screen the divider settles on when let go close to one,
/// as iPadOS's Split View does.
static const CGFloat LCSnapDetents[] = {1.0 / 3.0, 0.5, 2.0 / 3.0};
static const CGFloat LCSnapDetentReach = 0.05;
/// How much the first window's share changes for one VoiceOver adjustment.
static const CGFloat LCSnapAccessibilityStep = 0.1;

@interface LCWindowSnapManager () <LCSplitDividerViewDelegate>
@end

@implementation LCWindowSnapManager {
    __weak DecoratedAppSceneViewController *_first;
    __weak DecoratedAppSceneViewController *_second;
    /// The first half's share of the screen along the split.
    CGFloat _ratio;
    UIView *_preview;
    LCWindowSnapSlot _previewSlot;
    LCSplitDividerView *_divider;
    UISelectionFeedbackGenerator *_selectionFeedback;
}

+ (LCWindowSnapManager *)shared {
    static LCWindowSnapManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [LCWindowSnapManager new];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    _ratio = 0.5;
    _selectionFeedback = [UISelectionFeedbackGenerator new];
    return self;
}

#pragma mark - Geometry

/// The part of the screen windows snap into: inside the safe area, with a
/// margin all round.
- (CGRect)workAreaInView:(UIView *)hostView {
    UIEdgeInsets insets = hostView.window ? hostView.window.safeAreaInsets : hostView.safeAreaInsets;
    CGRect area = UIEdgeInsetsInsetRect(hostView.bounds, insets);
    return CGRectInset(area, LCSnapMargin, LCSnapMargin);
}

/// Whether the halves are stacked top and bottom, as in portrait, rather
/// than side by side.
- (BOOL)stacksVerticallyInArea:(CGRect)area {
    return area.size.height >= area.size.width;
}

/// How long the screen is along the split.
- (CGFloat)splitLengthInArea:(CGRect)area {
    return [self stacksVerticallyInArea:area] ? area.size.height : area.size.width;
}

- (CGRect)frameForSlot:(LCWindowSnapSlot)slot inView:(UIView *)hostView {
    CGRect area = [self workAreaInView:hostView];
    CGFloat length = [self splitLengthInArea:area];
    CGFloat split = round(length * _ratio);
    CGFloat halfGap = LCSnapGap / 2;
    CGRect frame = area;
    if ([self stacksVerticallyInArea:area]) {
        if (slot == LCWindowSnapSlotFirst) {
            frame.size.height = split - halfGap;
        } else {
            frame.origin.y += split + halfGap;
            frame.size.height = length - split - halfGap;
        }
    } else {
        if (slot == LCWindowSnapSlotFirst) {
            frame.size.width = split - halfGap;
        } else {
            frame.origin.x += split + halfGap;
            frame.size.width = length - split - halfGap;
        }
    }
    return frame;
}

- (CGRect)dividerFrameInView:(UIView *)hostView {
    CGRect area = [self workAreaInView:hostView];
    CGFloat split = round([self splitLengthInArea:area] * _ratio);
    CGFloat thickness = LCSnapGap + LCSnapDividerOverlap * 2;
    if ([self stacksVerticallyInArea:area]) {
        return CGRectMake(area.origin.x, area.origin.y + split - thickness / 2, area.size.width, thickness);
    }
    return CGRectMake(area.origin.x + split - thickness / 2, area.origin.y, thickness, area.size.height);
}

- (LCWindowSnapSlot)slotForFingerLocation:(CGPoint)location inView:(UIView *)hostView {
    CGRect area = [self workAreaInView:hostView];
    if ([self stacksVerticallyInArea:area]) {
        if (location.y <= CGRectGetMinY(area) + LCSnapTopZone) {
            return LCWindowSnapSlotFirst;
        }
        if (location.y >= CGRectGetMaxY(area) - LCSnapBottomZone) {
            return LCWindowSnapSlotSecond;
        }
    } else {
        if (location.x <= CGRectGetMinX(area) + LCSnapSideZone) {
            return LCWindowSnapSlotFirst;
        }
        if (location.x >= CGRectGetMaxX(area) - LCSnapSideZone) {
            return LCWindowSnapSlotSecond;
        }
    }
    return LCWindowSnapSlotNone;
}

/// The first window's share, kept so both windows get at least the least
/// room a window gets.
- (CGFloat)clampedRatio:(CGFloat)ratio length:(CGFloat)length {
    if (length <= 0) {
        return 0.5;
    }
    CGFloat minimum = MIN(0.45, (LCSnapMinimumLength + LCSnapGap / 2) / length);
    return MAX(minimum, MIN(1 - minimum, ratio));
}

#pragma mark - Preview

/// The glass outline of where a dragged window would go.
- (UIView *)preview {
    if (_preview) {
        return _preview;
    }
    UIView *preview = [[UIView alloc] init];
    preview.userInteractionEnabled = NO;
    preview.alpha = 0;
    preview.clipsToBounds = YES;
    preview.layer.cornerRadius = LCSnapPreviewCornerRadius;
    preview.layer.cornerCurve = kCACornerCurveContinuous;
    preview.layer.borderWidth = 1.0;
    preview.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.45].CGColor;

    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    glass.frame = preview.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [preview addSubview:glass];

    // A light wash, so it reads as a place for the window rather than glass.
    UIView *wash = [[UIView alloc] initWithFrame:preview.bounds];
    wash.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    wash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [preview addSubview:wash];

    _preview = preview;
    return preview;
}

- (void)showPreviewForWindow:(DecoratedAppSceneViewController *)window fingerLocation:(CGPoint)location {
    UIView *hostView = window.view.superview;
    if (!hostView) {
        return;
    }
    LCWindowSnapSlot slot = [self slotForFingerLocation:location inView:hostView];
    if (slot == LCWindowSnapSlotNone) {
        [self hidePreview];
        return;
    }

    // Under the dragged window, over the others.
    UIView *preview = [self preview];
    NSArray<UIView *> *subviews = hostView.subviews;
    if (preview.superview != hostView || [subviews indexOfObject:preview] > [subviews indexOfObject:window.view]) {
        [preview removeFromSuperview];
        [hostView insertSubview:preview belowSubview:window.view];
    }
    if (slot == _previewSlot) {
        return;
    }

    BOOL isAppearing = _previewSlot == LCWindowSnapSlotNone;
    _previewSlot = slot;
    CGRect target = [self frameForSlot:slot inView:hostView];
    if (isAppearing) {
        // It grows into place, out of a little smaller.
        preview.frame = CGRectInset(target, target.size.width * 0.04, target.size.height * 0.04);
    }
    [_selectionFeedback selectionChanged];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        preview.alpha = 1;
        preview.frame = target;
    } completion:nil];
}

- (void)hidePreview {
    if (_previewSlot == LCWindowSnapSlotNone) {
        return;
    }
    _previewSlot = LCWindowSnapSlotNone;
    UIView *preview = _preview;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        preview.alpha = 0;
    } completion:^(BOOL finished) {
        if (self->_previewSlot == LCWindowSnapSlotNone && preview.alpha == 0) {
            [preview removeFromSuperview];
        }
    }];
}

#pragma mark - Snapping

- (DecoratedAppSceneViewController *)windowInSlot:(LCWindowSnapSlot)slot {
    switch (slot) {
        case LCWindowSnapSlotFirst:
            return _first;
        case LCWindowSnapSlotSecond:
            return _second;
        default:
            return nil;
    }
}

- (void)setWindow:(DecoratedAppSceneViewController *)window inSlot:(LCWindowSnapSlot)slot {
    if (slot == LCWindowSnapSlotFirst) {
        _first = window;
    } else if (slot == LCWindowSnapSlotSecond) {
        _second = window;
    }
}

- (void)snapWindow:(DecoratedAppSceneViewController *)window toSlot:(LCWindowSnapSlot)slot {
    UIView *hostView = window.view.superview;
    if (!hostView || slot == LCWindowSnapSlotNone) {
        return;
    }
    // A window moving straight from one half to the other leaves the first.
    if (_first == window) {
        _first = nil;
    }
    if (_second == window) {
        _second = nil;
    }
    DecoratedAppSceneViewController *previous = [self windowInSlot:slot];
    if (previous) {
        [self setWindow:nil inSlot:slot];
        [previous didLeaveSnapRestoringFrame:YES];
    }
    [self setWindow:window inSlot:slot];
    [window didSnapToSlot:slot frame:[self frameForSlot:slot inView:hostView]];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self updateDividerInView:hostView];
}

- (void)releaseWindow:(DecoratedAppSceneViewController *)window {
    if (!window) {
        return;
    }
    if (_first == window) {
        _first = nil;
    }
    if (_second == window) {
        _second = nil;
    }
    if (window.snapSlot != LCWindowSnapSlotNone) {
        [window didLeaveSnapRestoringFrame:NO];
    }
    UIView *hostView = window.view.superview ?: _divider.superview;
    if (hostView) {
        [self updateDividerInView:hostView];
    }
}

- (CGRect)frameForWindow:(DecoratedAppSceneViewController *)window {
    UIView *hostView = window.view.superview;
    LCWindowSnapSlot slot = (LCWindowSnapSlot)window.snapSlot;
    if (!hostView || slot == LCWindowSnapSlotNone) {
        return CGRectNull;
    }
    return [self frameForSlot:slot inView:hostView];
}

#pragma mark - Layout

- (void)layoutInView:(UIView *)hostView {
    [self layoutSnappedWindowsInView:hostView animated:NO];
    [self updateDividerInView:hostView];
}

/// Puts the snapped windows and the divider where the split says.
- (void)layoutSnappedWindowsInView:(UIView *)hostView animated:(BOOL)animated {
    DecoratedAppSceneViewController *first = _first;
    DecoratedAppSceneViewController *second = _second;
    LCSplitDividerView *divider = _divider;
    void (^place)(void) = ^{
        if (first.view.superview == hostView) {
            first.view.frame = [self frameForSlot:LCWindowSnapSlotFirst inView:hostView];
            [first.view layoutIfNeeded];
        }
        if (second.view.superview == hostView) {
            second.view.frame = [self frameForSlot:LCWindowSnapSlotSecond inView:hostView];
            [second.view layoutIfNeeded];
        }
        if (divider.superview == hostView) {
            divider.frame = [self dividerFrameInView:hostView];
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.86 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:place completion:nil];
    } else {
        place();
    }
}

#pragma mark - Divider

/// Whether a window shows in each half, on this screen.
- (BOOL)showsBothHalvesInView:(UIView *)hostView {
    DecoratedAppSceneViewController *first = _first;
    DecoratedAppSceneViewController *second = _second;
    return first && second
        && first.view.superview == hostView && second.view.superview == hostView
        && !first.view.hidden && !second.view.hidden;
}

/// Shows the divider between the two snapped windows, or hides it when
/// there aren't two showing.
- (void)updateDividerInView:(UIView *)hostView {
    if (![self showsBothHalvesInView:hostView]) {
        LCSplitDividerView *divider = _divider;
        if (divider.superview) {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                divider.alpha = 0;
            } completion:^(BOOL finished) {
                if (divider.alpha == 0) {
                    [divider removeFromSuperview];
                }
            }];
        }
        return;
    }
    if (!_divider) {
        _divider = [[LCSplitDividerView alloc] initWithFrame:CGRectZero];
        _divider.delegate = self;
        _divider.gapWidth = LCSnapGap;
    }
    LCSplitDividerView *divider = _divider;
    divider.stacksVertically = [self stacksVerticallyInArea:[self workAreaInView:hostView]];
    divider.frame = [self dividerFrameInView:hostView];
    if (divider.superview != hostView) {
        [divider removeFromSuperview];
        divider.alpha = 0;
        [hostView addSubview:divider];
    } else {
        [self keepDividerOnTopInView:hostView];
    }
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        divider.alpha = 1;
    } completion:nil];
}

- (void)keepDividerOnTopInView:(UIView *)hostView {
    if (_divider.superview == hostView && hostView.subviews.lastObject != _divider) {
        [hostView bringSubviewToFront:_divider];
    }
}

- (void)windowVisibilityDidChange {
    UIView *hostView = _first.view.superview ?: _second.view.superview ?: _divider.superview;
    if (hostView) {
        [self updateDividerInView:hostView];
    }
}

#pragma mark - LCSplitDividerViewDelegate

- (void)splitDivider:(LCSplitDividerView *)divider didMoveBy:(CGFloat)delta {
    UIView *hostView = divider.superview;
    if (!hostView) {
        return;
    }
    CGFloat length = [self splitLengthInArea:[self workAreaInView:hostView]];
    if (length <= 0) {
        return;
    }
    CGFloat previous = _ratio;
    _ratio = [self clampedRatio:_ratio + delta / length length:length];
    // A tick as the divider passes the middle.
    if ((previous - 0.5) * (_ratio - 0.5) < 0) {
        [_selectionFeedback selectionChanged];
    }
    [self layoutSnappedWindowsInView:hostView animated:NO];
}

- (void)splitDividerDidEndMoving:(LCSplitDividerView *)divider {
    UIView *hostView = divider.superview;
    if (!hostView) {
        return;
    }
    for (size_t i = 0; i < sizeof(LCSnapDetents) / sizeof(LCSnapDetents[0]); i++) {
        if (fabs(_ratio - LCSnapDetents[i]) < LCSnapDetentReach) {
            _ratio = LCSnapDetents[i];
            break;
        }
    }
    _ratio = [self clampedRatio:_ratio length:[self splitLengthInArea:[self workAreaInView:hostView]]];
    [self layoutSnappedWindowsInView:hostView animated:YES];
}

- (void)splitDivider:(LCSplitDividerView *)divider adjustGrowingFirst:(BOOL)growsFirst {
    UIView *hostView = divider.superview;
    if (!hostView) {
        return;
    }
    CGFloat length = [self splitLengthInArea:[self workAreaInView:hostView]];
    _ratio = [self clampedRatio:_ratio + (growsFirst ? LCSnapAccessibilityStep : -LCSnapAccessibilityStep) length:length];
    [self layoutSnappedWindowsInView:hostView animated:YES];
}

@end

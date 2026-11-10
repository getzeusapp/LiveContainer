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

NSNotificationName const LCPhoneSplitDidChangeNotification = @"LCPhoneSplitDidChangeNotification";
/// Where an iPhone's split screen meets its divider, its apps' corners are
/// rounded, as other phones round them.
const CGFloat LCPhoneSplitCornerRadius = 22.0;
/// How close to the end of the screen the divider has to be let go for the
/// app beyond it to leave the split screen, as a share of the screen.
static const CGFloat LCPhoneSplitDismissShare = 0.1;
/// How dim the app about to leave gets while the divider is past that.
static const CGFloat LCPhoneSplitDismissAlpha = 0.45;
/// How long a request for a half waits for its app's window to open.
static const NSTimeInterval LCPhoneSplitRequestLifetime = 30.0;

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
    /// On iPhone: the half the next window to open goes into, and when that
    /// was asked for.
    LCWindowSnapSlot _pendingSlot;
    NSDate *_pendingDate;
    /// On iPhone: the black behind the split screen's two apps.
    UIView *_phoneBackdrop;
    /// On iPhone: where the finger has the divider, as a share of the screen,
    /// which can go past where the apps stop shrinking.
    CGFloat _fingerRatio;
    BOOL _awaitingSecond;
    NSString *_announcedFirstUUID;
}

+ (BOOL)usesPhoneLayout {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
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
/// margin all round. On iPhone, the whole screen: the apps go edge to edge,
/// and each keeps clear of the parts of the screen it covers itself.
- (CGRect)workAreaInView:(UIView *)hostView {
    if (LCWindowSnapManager.usesPhoneLayout) {
        return hostView.bounds;
    }
    UIEdgeInsets insets = hostView.window ? hostView.window.safeAreaInsets : hostView.safeAreaInsets;
    CGRect area = UIEdgeInsetsInsetRect(hostView.bounds, insets);
    return CGRectInset(area, LCSnapMargin, LCSnapMargin);
}

/// Whether the halves are stacked top and bottom, as in portrait, rather
/// than side by side.
- (BOOL)stacksVerticallyInArea:(CGRect)area {
    return area.size.height >= area.size.width;
}

- (BOOL)stacksVerticallyInView:(UIView *)hostView {
    return [self stacksVerticallyInArea:[self workAreaInView:hostView]];
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
    // On iPhone the app left in the other half fills the screen.
    if (LCWindowSnapManager.usesPhoneLayout) {
        if (_first == window || _second == window) {
            [self removePhoneSplitWindow:window];
        }
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
    // On iPhone the corners rounded toward the divider follow the split as
    // it turns, and the black behind the apps covers the screen.
    if (LCWindowSnapManager.usesPhoneLayout) {
        [first didMoveToSnapSlot:LCWindowSnapSlotFirst];
        [second didMoveToSnapSlot:LCWindowSnapSlotSecond];
        _phoneBackdrop.frame = hostView.bounds;
    }
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
    // On iPhone an app of the split screen going into the dock leaves it,
    // and fills the screen when it comes back. The other app fills the
    // screen now.
    if (LCWindowSnapManager.usesPhoneLayout) {
        DecoratedAppSceneViewController *first = _first;
        DecoratedAppSceneViewController *second = _second;
        DecoratedAppSceneViewController *hidden = first.view.hidden ? first : (second.view.hidden ? second : nil);
        if (hidden) {
            [self removePhoneSplitWindow:hidden];
            [hidden didLeavePhoneSplitAnimated:NO];
            return;
        }
    }
    UIView *hostView = _first.view.superview ?: _second.view.superview ?: _divider.superview;
    if (hostView) {
        [self updateDividerInView:hostView];
    }
}

#pragma mark - iPhone split screen

- (void)requestPhoneSplitSlot:(LCWindowSnapSlot)slot {
    _pendingSlot = slot;
    _pendingDate = NSDate.date;
}

- (void)cancelPhoneSplitRequest {
    _pendingSlot = LCWindowSnapSlotNone;
    _pendingDate = nil;
}

- (BOOL)claimPhoneSplitRequestForWindow:(DecoratedAppSceneViewController *)window {
    LCWindowSnapSlot slot = _pendingSlot;
    if (!LCWindowSnapManager.usesPhoneLayout || slot == LCWindowSnapSlotNone || !window.view.superview) {
        return NO;
    }
    BOOL isFresh = _pendingDate && -_pendingDate.timeIntervalSinceNow < LCPhoneSplitRequestLifetime;
    [self cancelPhoneSplitRequest];
    // The second half goes beside an app in the first.
    if (!isFresh || (slot == LCWindowSnapSlotSecond && (!_first || _first == window))) {
        return NO;
    }
    [self snapPhoneWindow:window toSlot:slot];
    return YES;
}

- (BOOL)isAwaitingSecondPhoneSplitApp {
    return _awaitingSecond;
}

- (NSString *)firstPhoneSplitDataUUID {
    return _first.dataUUID;
}

- (void)startPhoneSplitWithWindow:(DecoratedAppSceneViewController *)window {
    [self snapPhoneWindow:window toSlot:LCWindowSnapSlotFirst];
}

- (void)cancelPhoneSplit {
    DecoratedAppSceneViewController *first = _first;
    if (!first || _second) {
        return;
    }
    [self removePhoneSplitWindow:first];
    [first didLeavePhoneSplitAnimated:YES];
}

- (void)makeFullScreenFromPhoneSplit:(DecoratedAppSceneViewController *)window {
    DecoratedAppSceneViewController *other = _first == window ? _second : (_second == window ? _first : nil);
    if (!other) {
        [self cancelPhoneSplit];
        return;
    }
    // Its going into the dock takes it out of the split screen, and this
    // one fills the screen.
    [other minimizeWindow];
}

- (BOOL)prepareToAddPhoneSplitAppInView:(UIView *)hostView {
    if (!LCWindowSnapManager.usesPhoneLayout || !hostView) {
        return NO;
    }
    // A split screen, or one waiting for its second app, takes the new app
    // in its second half.
    DecoratedAppSceneViewController *first = _first;
    if (first && first.view.superview == hostView && !first.view.hidden) {
        return YES;
    }
    // Otherwise the frontmost app showing, if it fills the screen, moves up
    // to make room.
    for (UIView *view in hostView.subviews.reverseObjectEnumerator) {
        DecoratedAppSceneViewController *window = (id)view._viewDelegate;
        if (![window isKindOfClass:DecoratedAppSceneViewController.class] || view.hidden || view.alpha < 0.01) {
            continue;
        }
        if (!window.isMaximized) {
            return NO;
        }
        [self snapPhoneWindow:window toSlot:LCWindowSnapSlotFirst];
        return YES;
    }
    return NO;
}

/// Puts a window into a half of the split screen. The first half starts a
/// new one: the apps of one showing go into the dock. An app already in the
/// half goes into the dock too.
- (void)snapPhoneWindow:(DecoratedAppSceneViewController *)window toSlot:(LCWindowSnapSlot)slot {
    UIView *hostView = window.view.superview;
    if (!hostView || slot == LCWindowSnapSlotNone) {
        return;
    }
    NSMutableArray<DecoratedAppSceneViewController *> *leaving = [NSMutableArray array];
    for (DecoratedAppSceneViewController *other in @[_first ?: (id)NSNull.null, _second ?: (id)NSNull.null]) {
        if ((id)other == NSNull.null || other == window) {
            continue;
        }
        if (slot == LCWindowSnapSlotFirst || other == [self windowInSlot:slot]) {
            [leaving addObject:other];
        }
    }
    if (_first == window || [leaving containsObject:_first]) {
        _first = nil;
    }
    if (_second == window || [leaving containsObject:_second]) {
        _second = nil;
    }
    if (!_first && !_second) {
        _ratio = 0.5;
    }
    [self setWindow:window inSlot:slot];
    // In first, and out of the dock if it was there, so the apps leaving
    // don't find it hidden in its half as they go.
    [window didEnterPhoneSplitSlot:slot frame:[self frameForSlot:slot inView:hostView]];
    for (DecoratedAppSceneViewController *other in leaving) {
        [other minimizeWindow];
        [other didLeavePhoneSplitAnimated:NO];
    }
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self updatePhoneSplitInView:hostView];
}

/// Takes a window out of the split screen. The app in the other half fills
/// the screen. The window itself is left as it is.
- (void)removePhoneSplitWindow:(DecoratedAppSceneViewController *)window {
    UIView *hostView = window.view.superview ?: _divider.superview;
    DecoratedAppSceneViewController *other = _first == window ? _second : (_second == window ? _first : nil);
    _first = nil;
    _second = nil;
    [other didLeavePhoneSplitAnimated:YES];
    if (hostView) {
        [self updatePhoneSplitInView:hostView];
    }
}

/// Puts the black behind the two apps and the divider between them, and
/// tells the Home Screen whether the second half waits for an app.
- (void)updatePhoneSplitInView:(UIView *)hostView {
    DecoratedAppSceneViewController *first = _first;
    DecoratedAppSceneViewController *second = _second;
    if ([self showsBothHalvesInView:hostView]) {
        if (!_phoneBackdrop) {
            _phoneBackdrop = [[UIView alloc] init];
            _phoneBackdrop.backgroundColor = UIColor.blackColor;
            _phoneBackdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        _phoneBackdrop.frame = hostView.bounds;
        // Under the lower of the two, over any other app's window under them.
        NSArray<UIView *> *subviews = hostView.subviews;
        UIView *lower = [subviews indexOfObject:first.view] < [subviews indexOfObject:second.view] ? first.view : second.view;
        [_phoneBackdrop removeFromSuperview];
        [hostView insertSubview:_phoneBackdrop belowSubview:lower];
    } else {
        [_phoneBackdrop removeFromSuperview];
    }
    [self updateDividerInView:hostView];

    BOOL awaiting = first && !second && first.view.superview == hostView && !first.view.hidden;
    NSString *firstUUID = first.dataUUID;
    if (awaiting != _awaitingSecond || !(firstUUID == _announcedFirstUUID || [firstUUID isEqualToString:_announcedFirstUUID])) {
        _awaitingSecond = awaiting;
        _announcedFirstUUID = firstUUID;
        [NSNotificationCenter.defaultCenter postNotificationName:LCPhoneSplitDidChangeNotification object:self];
    }
}

/// While the divider is past where the app beyond it leaves on letting go,
/// that app dims.
- (void)updatePhoneSplitDismissHint {
    BOOL dismissesFirst = _fingerRatio < LCPhoneSplitDismissShare;
    BOOL dismissesSecond = _fingerRatio > 1 - LCPhoneSplitDismissShare;
    UIView *firstView = _first.view;
    UIView *secondView = _second.view;
    CGFloat firstAlpha = dismissesFirst ? LCPhoneSplitDismissAlpha : 1;
    CGFloat secondAlpha = dismissesSecond ? LCPhoneSplitDismissAlpha : 1;
    if (firstView.alpha == firstAlpha && secondView.alpha == secondAlpha) {
        return;
    }
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        firstView.alpha = firstAlpha;
        secondView.alpha = secondAlpha;
    } completion:nil];
}

#pragma mark - LCSplitDividerViewDelegate

- (void)splitDividerDidBeginMoving:(LCSplitDividerView *)divider {
    _fingerRatio = _ratio;
}

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
    _fingerRatio += delta / length;
    _ratio = [self clampedRatio:(LCWindowSnapManager.usesPhoneLayout ? _fingerRatio : _ratio + delta / length) length:length];
    // A tick as the divider passes the middle.
    if ((previous - 0.5) * (_ratio - 0.5) < 0) {
        [_selectionFeedback selectionChanged];
    }
    [self layoutSnappedWindowsInView:hostView animated:NO];
    if (LCWindowSnapManager.usesPhoneLayout) {
        // Past where the apps stop shrinking, the divider follows the finger
        // on toward the end of the screen.
        CGRect frame = [self dividerFrameInView:hostView];
        CGFloat overshoot = (_fingerRatio - _ratio) * length;
        divider.frame = [self stacksVerticallyInArea:[self workAreaInView:hostView]] ? CGRectOffset(frame, 0, overshoot) : CGRectOffset(frame, overshoot, 0);
        [self updatePhoneSplitDismissHint];
    }
}

- (void)splitDividerDidEndMoving:(LCSplitDividerView *)divider {
    UIView *hostView = divider.superview;
    if (!hostView) {
        return;
    }
    // On iPhone, let go near the end of the screen, the app beyond the
    // divider goes into the dock and the other fills the screen.
    if (LCWindowSnapManager.usesPhoneLayout) {
        DecoratedAppSceneViewController *leaving = nil;
        if (_fingerRatio < LCPhoneSplitDismissShare) {
            leaving = _first;
        } else if (_fingerRatio > 1 - LCPhoneSplitDismissShare) {
            leaving = _second;
        }
        _fingerRatio = _ratio;
        if (leaving) {
            [leaving minimizeWindow];
            return;
        }
        [self updatePhoneSplitDismissHint];
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

/// A double tap on the divider swaps the two apps, as on other phones.
- (void)splitDividerDidDoubleTap:(LCSplitDividerView *)divider {
    UIView *hostView = divider.superview;
    DecoratedAppSceneViewController *first = _first;
    DecoratedAppSceneViewController *second = _second;
    if (!hostView || ![self showsBothHalvesInView:hostView]) {
        return;
    }
    _first = second;
    _second = first;
    _ratio = 1 - _ratio;
    [second didMoveToSnapSlot:LCWindowSnapSlotFirst];
    [first didMoveToSnapSlot:LCWindowSnapSlotSecond];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
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

#import "LCHomeButtonViewController.h"
#import "LCHomeButtonPlacement.h"
#import "LCHomeButtonView.h"
#import <objc/message.h>

// The space between the button and the edges of the screen's safe area.
static const CGFloat LCHomeButtonEdgeMargin = 6;
// How long the button stays bright after a touch before it dims, and how
// bright it is then, like AssistiveTouch's idle opacity.
static const NSTimeInterval LCHomeButtonDimDelay = 3;
static const CGFloat LCHomeButtonDimmedAlpha = 0.4;
// How far a flung button carries on, in seconds of its speed when let go.
static const CGFloat LCHomeButtonFlingCarry = 0.12;

@interface LCHomeButtonViewController ()
@property (nonatomic) LCHomeButtonView *button;
// Where the button was moved to, or nil while it rests in its first place,
// which follows an iPad as it's turned.
@property (nonatomic, nullable) LCHomeButtonPlacement *placement;
// The black view over the app while zContainer opens.
@property (nonatomic, nullable) UIView *cover;
@property (nonatomic) BOOL isDragging;
// Where the finger holds the button, from the button's center.
@property (nonatomic) CGPoint dragOffset;
// Counts touches, so a dimming planned before the last touch doesn't happen.
@property (nonatomic) NSUInteger dimmingGeneration;
@end

@implementation LCHomeButtonViewController

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.clearColor;
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.placement = [LCHomeButtonPlacement savedPlacement];

    LCHomeButtonView *button = [[LCHomeButtonView alloc] initWithFrame:CGRectZero];
    [button addTarget:self action:@selector(buttonTouchedDown) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(buttonLetGo) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(buttonDragged:)]];
    [self.view addSubview:button];
    self.button = button;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self dimSoon];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.isDragging) {
        self.button.center = [self.currentPlacement centerInArea:self.restingArea];
    }
}

// Turning an iPad all the way round keeps the view's size, so it isn't laid
// out again on its own, but the first place moves to the other side.
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view setNeedsLayout];
    }];
}

// Where the button rests: where it was moved to, or else its first place,
// which on an iPad is beside the iPad's Home button as it's turned now.
- (LCHomeButtonPlacement *)currentPlacement {
    return self.placement ?: [LCHomeButtonPlacement firstPlacementForInterfaceOrientation:self.currentInterfaceOrientation];
}

// Which way the screen shows the app now.
- (UIInterfaceOrientation)currentInterfaceOrientation {
    UIWindowScene *scene = self.view.window.windowScene;
    if (!scene) {
        return UIInterfaceOrientationPortrait;
    }
    if (@available(iOS 16.0, *)) {
        return scene.effectiveGeometry.interfaceOrientation;
    }
    return scene.interfaceOrientation;
}

// The area the button's center rests in: the safe area, less the button's
// radius and a small margin.
- (CGRect)restingArea {
    CGRect safeArea = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat inset = LCHomeButtonView.diameter / 2 + LCHomeButtonEdgeMargin;
    CGRect area = CGRectInset(safeArea, inset, inset);
    if (CGRectIsNull(area) || CGRectIsEmpty(area)) {
        return CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    return area;
}

#pragma mark Touches

- (void)buttonTouchedDown {
    [self brighten];
}

- (void)buttonLetGo {
    [self dimSoon];
}

- (void)buttonPressed {
    [self dimSoon];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    if (self.pressHandler) {
        self.pressHandler();
    }
}

// Follows the finger, then lets the button settle against the edge nearest
// to where it was going when let go.
- (void)buttonDragged:(UIPanGestureRecognizer *)pan {
    CGPoint finger = [pan locationInView:self.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.isDragging = YES;
            self.dragOffset = CGPointMake(self.button.center.x - finger.x, self.button.center.y - finger.y);
            [self brighten];
            break;
        case UIGestureRecognizerStateChanged: {
            CGFloat radius = LCHomeButtonView.diameter / 2;
            CGRect bounds = CGRectInset(self.view.bounds, radius, radius);
            CGFloat x = finger.x + self.dragOffset.x;
            CGFloat y = finger.y + self.dragOffset.y;
            self.button.center = CGPointMake(MIN(MAX(x, CGRectGetMinX(bounds)), CGRectGetMaxX(bounds)),
                                             MIN(MAX(y, CGRectGetMinY(bounds)), CGRectGetMaxY(bounds)));
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            self.isDragging = NO;
            CGPoint velocity = [pan velocityInView:self.view];
            CGPoint heading = CGPointMake(self.button.center.x + velocity.x * LCHomeButtonFlingCarry,
                                          self.button.center.y + velocity.y * LCHomeButtonFlingCarry);
            CGRect area = self.restingArea;
            self.placement = [LCHomeButtonPlacement placementNearestToPoint:heading inArea:area];
            [self.placement save];
            CGPoint target = [self.placement centerInArea:area];
            [UIView animateWithDuration:0.45
                                  delay:0
                 usingSpringWithDamping:0.78
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.button.center = target;
            } completion:nil];
            [self dimSoon];
            break;
        }
        default:
            break;
    }
}

#pragma mark Dimming

- (void)brighten {
    self.dimmingGeneration += 1;
    [UIView animateWithDuration:0.15
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.button.alpha = 1;
    } completion:nil];
}

- (void)dimSoon {
    NSUInteger generation = ++self.dimmingGeneration;
    __weak LCHomeButtonViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCHomeButtonDimDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LCHomeButtonViewController *controller = weakSelf;
        if (!controller || controller.dimmingGeneration != generation || controller.isDragging || controller.button.isTracking) {
            return;
        }
        [UIView animateWithDuration:0.5
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            controller.button.alpha = LCHomeButtonDimmedAlpha;
        } completion:nil];
    });
}

#pragma mark Going back to zContainer

- (void)fadeOutWithCompletion:(void (^)(void))completion {
    [self.cover removeFromSuperview];
    UIView *cover = [[UIView alloc] initWithFrame:self.view.bounds];
    cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cover.backgroundColor = UIColor.blackColor;
    cover.alpha = 0;
    [self.view addSubview:cover];
    self.cover = cover;
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        cover.alpha = 1;
    } completion:^(BOOL finished) {
        completion();
    }];
}

- (void)fadeBackIn {
    UIView *cover = self.cover;
    self.cover = nil;
    [UIView animateWithDuration:0.25 animations:^{
        cover.alpha = 0;
    } completion:^(BOOL finished) {
        [cover removeFromSuperview];
    }];
    [self dimSoon];
}

#pragma mark Leaving the screen to the app

// The view controller of the app's main window that UIKit asks about the
// screen: the key window's (or else the first ordinary window's) root view
// controller, or the one it presents over everything.
- (nullable UIViewController *)appViewController {
    UIWindow *ownWindow = self.viewIfLoaded.window;
    UIWindow *appWindow = nil;
    for (UIWindow *window in ownWindow.windowScene.windows) {
        if (window == ownWindow || window.hidden || !window.rootViewController) {
            continue;
        }
        if (window.isKeyWindow) {
            appWindow = window;
            break;
        }
        if (!appWindow && window.windowLevel <= UIWindowLevelNormal) {
            appWindow = window;
        }
    }
    UIViewController *controller = appWindow.rootViewController;
    while (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
        controller = controller.presentedViewController;
    }
    return controller == self ? nil : controller;
}

// The view controller that decides the app's orientations, which UIKit finds
// with a private method of the root view controller when it has it.
- (nullable UIViewController *)appOrientationViewController {
    UIWindow *ownWindow = self.viewIfLoaded.window;
    UIViewController *controller = nil;
    for (UIWindow *window in ownWindow.windowScene.windows) {
        if (window != ownWindow && !window.hidden && window.isKeyWindow) {
            controller = window.rootViewController;
            break;
        }
    }
    if (!controller) {
        return self.appViewController;
    }
    SEL decider = NSSelectorFromString(@"_viewControllerForSupportedInterfaceOrientations");
    if ([controller respondsToSelector:decider]) {
        id found = ((id (*)(id, SEL))objc_msgSend)(controller, decider);
        if ([found isKindOfClass:UIViewController.class]) {
            controller = found;
        }
    }
    return controller == self ? nil : controller;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    UIInterfaceOrientationMask orientations = 0;
    @try {
        orientations = self.appOrientationViewController.supportedInterfaceOrientations;
    } @catch (NSException *exception) {
        orientations = 0;
    }
    // UIKit rejects an empty set of orientations.
    return orientations ?: UIInterfaceOrientationMaskAll;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return self.appViewController;
}

- (UIViewController *)childViewControllerForStatusBarHidden {
    return self.appViewController;
}

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden {
    return self.appViewController;
}

- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures {
    return self.appViewController;
}

@end

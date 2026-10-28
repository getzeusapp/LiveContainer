#import "DecoratedAppSceneViewController.h"
#import "ResizeHandleView.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "AppSceneViewController.h"
#import "UIKitPrivate+MultitaskSupport.h"
#import "PiPManager.h"
#import "VirtualWindowsHostView.h"
#import "LCWindowSnapManager.h"
#import "../LiveContainer/Localization.h"
#import "utils.h"
#include <notify.h>

/// A window's look, after iPadOS: continuous rounded corners and a soft
/// shadow in place of a border.
static const CGFloat LCWindowCornerRadius = 22.0;
/// A maximized window fills the screen edge to edge, so the screen's own
/// corners round it.
static const CGFloat LCMaximizedWindowCornerRadius = 0.0;
static const CGFloat LCWindowShadowOpacity = 0.28;
/// The close, minimize and maximize dots in the title bar's leading corner.
static const CGFloat LCWindowControlDiameter = 14.0;
/// Each dot's share of the row: close together, as on iPadOS, but the full
/// height of the title bar.
static const CGSize LCWindowControlSize = {26.0, 44.0};
/// How far beyond the row a touch still counts.
static const CGFloat LCWindowControlTouchSlop = 12.0;
/// How far past the window's bottom-right corner a touch still grabs the
/// resize handle. Fingers often land just outside the corner, where nothing
/// would take them.
static const CGFloat LCResizeHandleOuterSlop = 24.0;
/// How much of a tucked-away window stays on screen, as the tab that brings
/// it back.
static const CGFloat LCStashTabWidth = 30.0;
/// How fast a fling toward the side has to be to tuck the window away.
static const CGFloat LCStashFlingVelocity = 1100.0;
/// How much of a window has to be past the side, when it's let go, to tuck
/// it away.
static const CGFloat LCStashOffscreenShare = 0.45;
/// Space between a window brought back out and the side it comes from.
static const CGFloat LCStashReturnMargin = 6.0;
/// How long a window takes to go into the multitask dock or come back out.
static const NSTimeInterval LCDockAnimationDuration = 0.45;
/// How far into going into the dock a window starts to fade, and how far
/// into coming back out it has faded in.
static const CGFloat LCDockFadeShare = 0.35;

/// A window's outer view. It doesn't clip, so its shadow can show; the title
/// bar and the app clip themselves to the corners instead
/// (`updateCornerMasks`). It keeps the shadow's path in step with its size,
/// so the shadow isn't worked out from the app's pixels on every frame.
@interface LCWindowView : UIStackView
/// The resize handle, which also takes touches just past the window's
/// bottom-right corner.
@property(nonatomic, weak) UIView *resizeHandle;
@end

@implementation LCWindowView
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

/// The frame the window has without its transform, as it grows out of the
/// multitask dock or bounces as it comes to the front. UIKit leaves a
/// transformed view's frame undefined, and setting it then would size the
/// window for the transform, so it would end up the wrong size.
- (CGRect)frame {
    if (CGAffineTransformIsIdentity(self.transform)) {
        return super.frame;
    }
    CGSize size = self.bounds.size;
    CGPoint center = self.center;
    return CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height);
}

- (void)setFrame:(CGRect)frame {
    if (CGAffineTransformIsIdentity(self.transform)) {
        super.frame = frame;
        return;
    }
    self.bounds = (CGRect){self.bounds.origin, frame.size};
    self.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

/// Where a touch grabs the resize handle: the handle itself, and as far
/// again past the window's right and bottom edges. Nowhere while the handle
/// doesn't show, as when the window fills the screen or a half of it.
- (CGRect)resizeGrabArea {
    UIView *handle = self.resizeHandle;
    if (!handle || handle.hidden || handle.alpha < 0.01 || !handle.userInteractionEnabled) {
        return CGRectNull;
    }
    CGRect area = handle.frame;
    area.size.width += LCResizeHandleOuterSlop;
    area.size.height += LCResizeHandleOuterSlop;
    return area;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [super pointInside:point withEvent:event] || CGRectContainsPoint([self resizeGrabArea], point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.hidden && self.alpha >= 0.01 && self.userInteractionEnabled && CGRectContainsPoint([self resizeGrabArea], point)) {
        return self.resizeHandle;
    }
    return [super hitTest:point withEvent:event];
}

/// The divider between two snapped windows shows only while both do, and
/// the multitask dock marks which windows show.
- (void)setHidden:(BOOL)hidden {
    BOOL changed = hidden != self.hidden;
    [super setHidden:hidden];
    if (changed) {
        [LCWindowSnapManager.shared windowVisibilityDidChange];
        [MultitaskDockManager.shared refreshWindowVisibility];
    }
}
@end

/// The row of window controls. The dots are small and close together, so
/// the row takes any touch on or near it and gives it to the closest dot,
/// rather than leaving each its own small square.
@interface LCWindowControlsView : UIStackView
@end

@implementation LCWindowControlsView
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(CGRectInset(self.bounds, -LCWindowControlTouchSlop, -LCWindowControlTouchSlop), point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !self.userInteractionEnabled || ![self pointInside:point withEvent:event]) {
        return nil;
    }
    UIView *nearest = nil;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (UIView *control in self.arrangedSubviews) {
        CGFloat distance = hypot(point.x - control.center.x, point.y - control.center.y);
        if (distance < nearestDistance) {
            nearestDistance = distance;
            nearest = control;
        }
    }
    return nearest;
}
@end

@interface DecoratedAppSceneViewController()
@property(nonatomic) NSArray* activatedVerticalConstraints;
@property(nonatomic) NSString* dataUUID;
@property(nonatomic) int pid;
@property(nonatomic) CGRect originalFrame;
/// The green dots: the title bar's and the floating one's.
@property(nonatomic) NSMutableArray<UIButton *> *maximizeControls;
/// The window controls over the app's top-leading corner while the window
/// fills the screen and has no title bar. Hidden until asked for: by a tap
/// on the leading half of the status bar, or on the multitask dock
/// (`revealWindowControls`). Touches on the app itself go to its own scene,
/// so the window can't watch for a gesture there.
@property(nonatomic) UIView *floatingControls;
/// Counts reveals, so only the latest one's timer hides the controls.
@property(nonatomic) NSUInteger floatingControlsReveal;
@property(nonatomic) bool isAppTerminationRequested;
@property(nonatomic) bool isObservingWindowBar;
@property(nonatomic, readwrite) NSInteger snapSlot;
/// The window's frame before it snapped, which it goes back to when another
/// window takes its half, and whose size it gets back when dragged out.
@property(nonatomic) CGRect frameBeforeSnap;
/// Where the window was as the drag that moves it began.
@property(nonatomic) CGRect frameAtDragStart;
@property(nonatomic, readwrite) BOOL isStashed;
/// Whether a tucked-away window is tucked into the left side, rather than
/// the right.
@property(nonatomic) BOOL stashesLeft;
/// The tab a tucked-away window shows over the sliver of it left on screen.
/// A tap brings the window back; a drag pulls it out.
@property(nonatomic) UIVisualEffectView *stashTab;
/// Whether the window is being dragged by its title bar or tab, which
/// places it until the drag ends.
@property(nonatomic) BOOL isBeingDragged;
/// The registration for the notification the app posts as it's touched.
@property(nonatomic) int touchNotifyToken;
@property(nonatomic) BOOL isListeningForAppTouches;
/// The picture of the window on its way into the multitask dock, while it
/// goes.
@property(nonatomic, weak) UIView *dockFlyer;
@end

@implementation DecoratedAppSceneViewController
- (instancetype)initWindowName:(NSString*)windowName bundleId:(NSString*)bundleId dataUUID:(NSString*)dataUUID rootVC:(UIViewController*)rootVC {
    self = [super initWithNibName:nil bundle:nil];
    self.view = [[LCWindowView alloc] initWithFrame:self.view.frame];
    [MultitaskDockManager.shared.windowHostingView addSubview:self.view];
    [rootVC addChildViewController:self];
    
    _dataUUID = dataUUID;
    _scaleRatio = 1.0;
    [self listenForAppTouches];
    _isMaximized = [NSUserDefaults.lcUserDefaults boolForKey:@"LCLaunchMultitaskMaximized"];
    _appSceneVC = [[AppSceneViewController alloc] initWithBundleId:bundleId dataUUID:dataUUID delegate:self];
    self.title = windowName;
    [self setupDecoratedView];
    
    [MultitaskDockManager.shared addRunningApp:windowName appUUID:dataUUID view:self.view];
    
    // The title menu keeps these, so they hold the window weakly
    __weak typeof(self) weakSelf = self;
    NSArray *menuItems = @[
        [UIAction actionWithTitle:@"lc.multitask.copyPid".loc image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = @(weakSelf.appSceneVC.pid).stringValue;
        }],
        [UIAction actionWithTitle:@"lc.multitask.enablePip".loc image:[UIImage systemImageNamed:@"pip.enter"] identifier:nil handler:^(UIAction * _Nonnull action) {
            AppSceneViewController *appSceneVC = weakSelf.appSceneVC;
            if ([PiPManager.shared isPiPWithVC:appSceneVC]) {
                [PiPManager.shared stopPiP];
            } else {
                [PiPManager.shared startPiPWithVC:appSceneVC];
            }
        }],
        [UICustomViewMenuElement elementWithViewProvider:^UIView *(UICustomViewMenuElement *element) {
            return [weakSelf scaleSliderViewWithTitle:@"lc.multitask.scale".loc min:0.5 max:2.0 value:weakSelf.scaleRatio stepInterval:0.01];
        }]
    ];
    

    [self.navigationItem setTitleMenuProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions){
        if(!weakSelf.appSceneVC.isAppRunning) {
            return [UIMenu menuWithTitle:NSLocalizedString(@"lc.multitaskAppWindow.appTerminated", nil) children:@[]];
        } else {
            NSString *pidText = [NSString stringWithFormat:@"PID: %d", weakSelf.pid];
            return [UIMenu menuWithTitle:pidText children:menuItems];
        }
    }];
    
    // iPadOS's window controls: close, minimize and maximize as colored dots
    // in the leading corner, wherever the bar is. On their own, without the
    // glass capsule iOS 26 puts behind a navigation bar's items.
    UIBarButtonItem *controlsItem = [[UIBarButtonItem alloc] initWithCustomView:[self windowControlsView]];
    if (@available(iOS 26.0, *)) {
        controlsItem.hidesSharedBackground = YES;
    }
    self.navigationItem.leftBarButtonItem = controlsItem;

    return self;
}

- (void)setupDecoratedView {
    CGFloat navBarHeight = 44;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(UIApp.statusBarOrientation);
    CGRect frame = CGRectMake(0, 0, isLandscape ? 480 : 320, (isLandscape ? 320 : 480) + navBarHeight);
    CGPoint rootViewCenter = self.view.superview.center;
    frame.origin = CGPointMake(rootViewCenter.x - frame.size.width / 2, rootViewCenter.y - frame.size.height / 2);
    
    if(_isMaximized) {
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        // save origin as normalized coordinates
        frame.origin.x /= maxFrame.size.width;
        frame.origin.y /= maxFrame.size.height;
        self.originalFrame = frame;
    } else {
        self.view.frame = frame;
    }
    
    // Navigation bar
    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, navBarHeight)];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:self.title];
    navigationBar.items = @[navigationItem];
    // A quiet title bar, as on iPadOS: material, no hairline, a smaller title.
    UINavigationBarAppearance *barAppearance = [UINavigationBarAppearance new];
    [barAppearance configureWithDefaultBackground];
    barAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    barAppearance.shadowColor = nil;
    barAppearance.titleTextAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
    };
    navigationBar.standardAppearance = barAppearance;
    navigationBar.compactAppearance = barAppearance;
    navigationBar.scrollEdgeAppearance = barAppearance;
    
    self.view.axis = UILayoutConstraintAxisVertical;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.layer.cornerCurve = kCACornerCurveContinuous;
    self.view.layer.masksToBounds = NO;
    self.view.layer.shadowColor = UIColor.blackColor.CGColor;
    self.view.layer.shadowOffset = CGSizeMake(0, 8);
    self.view.layer.shadowRadius = 24;

    self.navigationBar = navigationBar;
    self.navigationItem = navigationBar.items.firstObject;
    if (!self.navigationBar.superview) {
        [self.view addArrangedSubview:self.navigationBar];
    }
    
    CGRect contentFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - navBarHeight);
    UIView *fixedPositionContentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if([NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"]) {
        [self.view insertArrangedSubview:fixedPositionContentView atIndex:0];
    } else {
        [self.view addArrangedSubview:fixedPositionContentView];
    }
    [self.view sendSubviewToBack:fixedPositionContentView];
    
    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.layer.anchorPoint = self.contentView.layer.position = CGPointMake(0, 0);
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [fixedPositionContentView addSubview:self.contentView];
    
    UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
    moveGesture.minimumNumberOfTouches = 1;
    moveGesture.maximumNumberOfTouches = 1;
    [self.navigationBar addGestureRecognizer:moveGesture];

    // Resize handle (idea stolen from Notes debugging window)
    UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeWindow:)];
    resizeGesture.minimumNumberOfTouches = 1;
    resizeGesture.maximumNumberOfTouches = 1;
    self.resizeHandle = [[ResizeHandleView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - navBarHeight, self.view.frame.size.height - navBarHeight, navBarHeight, navBarHeight)];
    self.resizeHandle.alpha = _isMaximized ? 0.0 : 1.0;
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [self.view addSubview:self.resizeHandle];
    ((LCWindowView *)self.view).resizeHandle = self.resizeHandle;
    
    [self addChildViewController:_appSceneVC];
    [self.view insertSubview:_appSceneVC.view atIndex:0];

    self.floatingControls = [self windowControlsView];
    self.floatingControls.translatesAutoresizingMaskIntoConstraints = NO;
    self.floatingControls.alpha = 0;
    self.floatingControls.hidden = YES;
    // A shadow keeps the dots readable over whatever the app draws there.
    self.floatingControls.layer.shadowColor = UIColor.blackColor.CGColor;
    self.floatingControls.layer.shadowOpacity = 0.3;
    self.floatingControls.layer.shadowRadius = 3;
    self.floatingControls.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:self.floatingControls];
    [NSLayoutConstraint activateConstraints:@[
        [self.floatingControls.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:6],
        [self.floatingControls.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-4],
    ]];

    [self applyWindowStyleMaximized:_isMaximized];
    _appSceneVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self updateVerticalConstraints];
    [NSLayoutConstraint activateConstraints:@[
        [_appSceneVC.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_appSceneVC.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    
    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults;

    [defaults addObserver:self forKeyPath:@"LCMultitaskBottomWindowBar" options:NSKeyValueObservingOptionNew context:NULL];
    self.isObservingWindowBar = true;
    [self updateOriginalFrame];
}


// Stolen from UIKitester
- (UIView *)scaleSliderViewWithTitle:(NSString *)title min:(CGFloat)minValue max:(CGFloat)maxValue value:(CGFloat)initialValue stepInterval:(CGFloat)step {
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.exclusiveTouch = YES;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 0.0;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:10.0],
        [stackView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8.0],
        [stackView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16.0],
        [stackView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16.0]
    ]];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont boldSystemFontOfSize:12.0];
    [stackView addArrangedSubview:label];
    
    _UIPrototypingMenuSlider *slider = [[_UIPrototypingMenuSlider alloc] init];
    slider.minimumValue = minValue;
    slider.maximumValue = maxValue;
    slider.value = initialValue;
    slider.stepSize = step;
    
    NSLayoutConstraint *sliderHeight = [slider.heightAnchor constraintEqualToConstant:40.0];
    sliderHeight.active = YES;
    
    [stackView addArrangedSubview:slider];
    
    [slider addTarget:self action:@selector(scaleSliderChanged:) forControlEvents:UIControlEventValueChanged];
    
    return containerView;
}

- (void)scaleSliderChanged:(_UIPrototypingMenuSlider *)slider {
    self.scaleRatio = slider.value;
    self.appSceneVC.scaleRatio = _scaleRatio;
    if(self.appSceneVC.usesHostingControllerAPI) {
        self.appSceneVC.contentView.transform = CGAffineTransformMakeScale(_scaleRatio, _scaleRatio);
    } else {
        self.appSceneVC.contentView.layer.sublayerTransform = CATransform3DMakeScale(_scaleRatio, _scaleRatio, 1.0);
    }
    __weak typeof(self) weakSelf = self;
    [self.appSceneVC updateFrameWithSettingsBlock:^(UIMutableApplicationSceneSettings *settings) {
        if(weakSelf.isMaximized) {
            [weakSelf updateMaximizedSafeAreaWithSettings:settings];
        } else {
            // it seems some apps don't honor these settings so we don't cover the top of the app
            settings.peripheryInsets = UIEdgeInsetsZero;
            settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
        }
    }];
}

- (void)closeWindow {
    _isAppTerminationRequested = true;
    if([_appSceneVC isAppRunning]) {
        [_appSceneVC terminate];
    } else {
        [self appSceneVCAppDidExit:self.appSceneVC];
    }
}

- (void)minimizeWindow {
    if (self.view.hidden) return;
    // A picture of the window goes into the dock in its place, and the
    // window itself hides at once, untouched: nothing that moves or resizes
    // the window meanwhile can throw the animation off, and the app isn't
    // scaled on the way.
    [self.view.layer removeAllAnimations];
    self.view.transform = CGAffineTransformIdentity;
    UIView *hostView = self.view.superview;
    UIView *flyer = hostView ? [self pictureOfWindow] : nil;
    if (flyer) {
        // Over the other windows, under the dock it goes into.
        [hostView addSubview:flyer];
    }
    [self hideInDock];
    if (!flyer) return;
    self.dockFlyer = flyer;

    void (^landed)(BOOL) = ^(BOOL finished) {
        [flyer removeFromSuperview];
    };
    CGRect icon = [MultitaskDockManager.shared iconFrameForAppUUID:self.dataUUID in:hostView];
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    if (CGRectIsNull(icon) || reduceMotion) {
        // With no dock showing, or with Reduce Motion on, it fades away
        // where it is.
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            flyer.alpha = 0;
            if (!reduceMotion) {
                flyer.transform = CGAffineTransformMakeScale(0.85, 0.85);
            }
        } completion:landed];
        return;
    }
    // Into its app's icon, as a Mac window goes into the Dock: it shrinks
    // as it sets off, follows into the icon, and fades there.
    CGFloat scale = [self scaleIntoRect:icon];
    [UIView animateWithDuration:LCDockAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        flyer.center = CGPointMake(CGRectGetMidX(icon), CGRectGetMidY(icon));
    } completion:landed];
    [UIView animateWithDuration:LCDockAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        flyer.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
    [UIView animateWithDuration:LCDockAnimationDuration * LCDockFadeShare delay:LCDockAnimationDuration * (1 - LCDockFadeShare) options:UIViewAnimationOptionCurveEaseIn animations:^{
        flyer.alpha = 0;
    } completion:nil];
}

/// A picture of the window where it is, with its corners and shadow, to go
/// into the dock in its place. Nil when there's nothing to picture.
- (UIView *)pictureOfWindow {
    if (CGRectIsEmpty(self.view.bounds)) return nil;
    UIView *picture = [self.view snapshotViewAfterScreenUpdates:NO];
    if (!picture) return nil;
    UIView *flyer = [[UIView alloc] initWithFrame:self.view.frame];
    flyer.userInteractionEnabled = NO;
    picture.frame = flyer.bounds;
    [flyer addSubview:picture];
    // The picture stops at the window's edges, so its shadow goes around it.
    CALayer *windowLayer = self.view.layer;
    flyer.layer.shadowColor = windowLayer.shadowColor;
    flyer.layer.shadowOpacity = windowLayer.shadowOpacity;
    flyer.layer.shadowRadius = windowLayer.shadowRadius;
    flyer.layer.shadowOffset = windowLayer.shadowOffset;
    flyer.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:flyer.bounds cornerRadius:windowLayer.cornerRadius].CGPath;
    return flyer;
}

/// Hides the window as it goes into the dock, and sends it behind the
/// others, so the dock brings it back in front.
- (void)hideInDock {
    self.view.hidden = YES;
    [self.view.superview sendSubviewToBack:self.view];
    // A tucked-away window comes back out while it's hidden, so it shows on
    // screen when the multitask dock brings it back.
    if (self.isStashed) {
        [self unstashAnimated:NO];
    }
}

- (void)restoreFromDock {
    // A window brought back before its picture reached the dock comes
    // straight back out.
    [self.dockFlyer removeFromSuperview];
    [self.view.layer removeAllAnimations];
    self.view.transform = CGAffineTransformIdentity;
    UIView *hostView = self.view.superview;
    CGRect icon = hostView ? [MultitaskDockManager.shared iconFrameForAppUUID:self.dataUUID in:hostView] : CGRectNull;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction;
    if (CGRectIsNull(icon) || reduceMotion) {
        // With no dock showing, or with Reduce Motion on, it fades in where
        // it is.
        self.view.alpha = 0;
        if (!reduceMotion) {
            self.view.transform = CGAffineTransformMakeScale(0.85, 0.85);
        }
        self.view.hidden = NO;
        [UIView animateWithDuration:0.25 delay:0 options:options | UIViewAnimationOptionCurveEaseOut animations:^{
            self.view.alpha = 1;
            self.view.transform = CGAffineTransformIdentity;
        } completion:nil];
        return;
    }
    // Out of its app's icon, the way it went in: it leaves the icon small
    // and grows as it gets back to where it was. Its size stays as it is, so
    // the app isn't resized on the way.
    CGPoint center = self.view.center;
    self.view.center = CGPointMake(CGRectGetMidX(icon), CGRectGetMidY(icon));
    CGFloat scale = [self scaleIntoRect:icon];
    self.view.transform = CGAffineTransformMakeScale(scale, scale);
    self.view.alpha = 0;
    self.view.hidden = NO;
    [UIView animateWithDuration:LCDockAnimationDuration delay:0 options:options | UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.center = center;
    } completion:nil];
    [UIView animateWithDuration:LCDockAnimationDuration delay:0 options:options | UIViewAnimationOptionCurveEaseIn animations:^{
        self.view.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:LCDockAnimationDuration * LCDockFadeShare delay:0 options:options | UIViewAnimationOptionCurveEaseOut animations:^{
        self.view.alpha = 1;
    } completion:nil];
}

/// How much to shrink the window for it to fit in `rect`.
- (CGFloat)scaleIntoRect:(CGRect)rect {
    CGSize size = self.view.bounds.size;
    return MIN(rect.size.width, rect.size.height) / MAX(MAX(size.width, size.height), 1);
}

- (void)minimizeWindowPiP {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.hidden = YES;
    }];
}

- (void)unminimizeWindowPiP {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.hidden = NO;
        self.view.alpha = 1;
    } completion:nil];
}

- (void)maximizeWindow {
    void (^updateSettingsBlock)(UIMutableApplicationSceneSettings *settings);
    
    [self.view layoutIfNeeded];
    if (self.isMaximized) {
        updateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings) {
            [self updateWindowedFrameWithSettings:settings];
        };
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
        // The title bar comes back as the window shrinks, not after.
        self.isMaximized = NO;
        [self updateVerticalConstraints];
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            [self applyWindowStyleMaximized:NO];
            self.resizeHandle.alpha = 1;
            
            [self.appSceneVC updateSettingsWithBlock:updateSettingsBlock];
            
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self updateMaximizeControl];
        }];
    } else {
        updateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings) {
            [self updateMaximizedFrameWithSettings:settings];
        };
        if (self.isStashed) {
            [self unstashAnimated:NO];
        }
        if (self.snapSlot != LCWindowSnapSlotNone) {
            // Full screen takes the window out of its half. Leaving full
            // screen brings it back as it was before it snapped.
            CGRect before = self.frameBeforeSnap;
            [LCWindowSnapManager.shared releaseWindow:self];
            if (!CGRectIsEmpty(before)) {
                [self updateOriginalFrameFromFrame:before];
            }
        } else {
            [self updateOriginalFrame];
        }
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.isMaximized = YES;
            [self updateVerticalConstraints];
            
            [self applyWindowStyleMaximized:YES];
            self.resizeHandle.alpha = 0;
            
            [self.appSceneVC updateSettingsWithBlock:updateSettingsBlock];
            
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self updateMaximizeControl];
        }];
    }
}

- (void)appSceneVCAppDidExit:(AppSceneViewController*)vc {
    BOOL skipTerminationScreen = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCSkipTerminatedScreen"];
    BOOL isManual = _isAppTerminationRequested;
    if(isManual || skipTerminationScreen) {
        
        MultitaskDockManager *dock = [MultitaskDockManager shared];
        [dock removeRunningApp:self.dataUUID];
        [LCWindowSnapManager.shared releaseWindow:self];
        [self stopListeningForAppTouches];
        
        // Closing shrinks and fades the window away, as iPadOS does.
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.view.transform = CGAffineTransformMakeScale(0.85, 0.85);
            self.view.alpha = 0;
        } completion:^(BOOL b){
            [self.view removeFromSuperview];
            // Let the closed window go: nothing else lays it out or holds it
            [self stopObservingWindowBar];
            [self willMoveToParentViewController:nil];
            [self removeFromParentViewController];
        }];
        
        if(skipTerminationScreen) {
            [MultitaskRelaunchManager scheduleRelaunchIfNeededWithBundleId:self.appSceneVC.bundleId dataUUID:self.dataUUID isManualTermination:isManual];
        }
    } else {
        UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.numberOfLines = 0;
        label.text = NSLocalizedString(@"lc.multitaskAppWindow.appTerminated", @"");
        label.textAlignment = NSTextAlignmentCenter;
        [self.view insertSubview:label atIndex:0];
    }
}

- (void)appSceneVC:(AppSceneViewController*)vc didInitializeWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(error) {
            [vc appTerminationCleanUp];
            // The launch waiting on this window ends with the error, rather
            // than waiting forever and leaving the app marked as running.
            if (self.pidAvailableHandler) {
                self.pidAvailableHandler(nil, error);
                self.pidAvailableHandler = nil;
                // The launch shows the error itself.
                return;
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"lc.common.error".loc message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.ok".loc style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.copy".loc style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = error.localizedDescription;
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            self.pid = vc.pid;
            [self updateOriginalFrame];
            if (self.pidAvailableHandler) {
                self.pidAvailableHandler(@(self.pid), nil);
                self.pidAvailableHandler = nil;
            }
        }
    });
}

- (void)appSceneVCWillActivateScene:(AppSceneViewController *)vc {
    // Set up initial settings such as frame, safe area, etc
    [self appSceneVC:vc didUpdateFromSettings:vc.presenter.scene.settings.mutableCopy transitionContext:nil lifecycleActionType:0];
}

- (void)appSceneVC:(AppSceneViewController*)vc didUpdateFromSettings:(UIMutableApplicationSceneSettings *)baseSettings transitionContext:(id)newContext lifecycleActionType:(uint32_t)actionType {
    [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.userInterfaceStyle = baseSettings.userInterfaceStyle;
        settings.interfaceOrientation = baseSettings.interfaceOrientation;
        settings.deviceOrientation = baseSettings.deviceOrientation;
        settings.foreground = YES;
        
        if(self.isMaximized) {
            [self updateMaximizedFrameWithSettings:settings];
        } else {
            [self updateWindowedFrameWithSettings:settings];
        }
        CGRect newFrame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - self.navigationBar.frame.size.height/self.scaleRatio);
        
        if(UIInterfaceOrientationIsLandscape(baseSettings.interfaceOrientation)) {
            settings.frame = CGRectMake(0, 0, newFrame.size.height, newFrame.size.width);
        } else {
            settings.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.3 animations:^{
        BOOL bottomWindowBar = [change[NSKeyValueChangeNewKey] boolValue];
        // The window controls stay in the leading corner either way.
        if(bottomWindowBar) {
            [self.view addArrangedSubview:self.navigationBar];
        } else {
            [self.view insertArrangedSubview:self.navigationBar atIndex:0];
        }
        
        [self updateVerticalConstraints];
        
        if(_isMaximized) {
            [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                [self updateMaximizedFrameWithSettings:settings];
            }];
        }
        [self.view layoutIfNeeded];
    }];
}

- (void)stopObservingWindowBar {
    // The exit callback can run twice for one window
    if(!self.isObservingWindowBar) return;
    self.isObservingWindowBar = false;
    [NSUserDefaults.lcSharedDefaults removeObserver:self forKeyPath:@"LCMultitaskBottomWindowBar"];
}

- (void)dealloc {
    [self stopObservingWindowBar];
    [self stopListeningForAppTouches];
}

/// A touch on the app itself goes straight to it, past this window, so the
/// app says so with a notification named for its container (see
/// UIKit+GuestHooks.m), and the window comes to the front for it.
- (void)listenForAppTouches {
    NSString *name = [NSString stringWithFormat:@"%s%@", LC_WINDOW_TOUCHED_NOTIFICATION_PREFIX, self.dataUUID];
    __weak typeof(self) weakSelf = self;
    int token = 0;
    uint32_t status = notify_register_dispatch(name.UTF8String, &token, dispatch_get_main_queue(), ^(int receivedToken) {
        [weakSelf raiseForTouch];
    });
    if (status == NOTIFY_STATUS_OK) {
        self.touchNotifyToken = token;
        self.isListeningForAppTouches = YES;
    }
}

- (void)stopListeningForAppTouches {
    if (!self.isListeningForAppTouches) {
        return;
    }
    self.isListeningForAppTouches = NO;
    notify_cancel(self.touchNotifyToken);
}

- (void)moveWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized) return;
    UIView *hostView = self.view.superview;
    if (!hostView) return;
    LCWindowSnapManager *snapManager = LCWindowSnapManager.shared;
    CGPoint finger = [sender locationInView:hostView];

    self.isBeingDragged = sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateChanged;
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGRect start = self.view.frame;
        if (self.isStashed) {
            start = [self frameOutOfStash:self.view.frame];
            [self leaveStashForDrag];
        }
        if (self.snapSlot != LCWindowSnapSlotNone) {
            [self leaveSnapUnderFinger:finger];
            start = self.view.frame;
        }
        self.frameAtDragStart = start;
    }

    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];
    self.view.center = CGPointMake(self.view.center.x + point.x, self.view.center.y + point.y);

    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            [snapManager showPreviewForWindow:self fingerLocation:finger];
            [self updateOriginalFrame];
            break;
        case UIGestureRecognizerStateEnded:
            [snapManager hidePreview];
            [self finishMoveWithFinger:finger velocity:[sender velocityInView:hostView]];
            break;
        default:
            [snapManager hidePreview];
            [self updateOriginalFrame];
            break;
    }
}

/// Where a window goes as the drag that moves it ends: into a half when the
/// finger is at an edge that snaps, into the side when it's flung there or
/// is mostly past it, or it stays where it was let go.
- (void)finishMoveWithFinger:(CGPoint)finger velocity:(CGPoint)velocity {
    LCWindowSnapManager *snapManager = LCWindowSnapManager.shared;
    BOOL isFlungSideways = fabs(velocity.x) > LCStashFlingVelocity && fabs(velocity.x) > fabs(velocity.y) * 1.5;
    LCWindowSnapSlot slot = [snapManager slotForFingerLocation:finger inView:self.view.superview];
    if (slot != LCWindowSnapSlotNone && !isFlungSideways) {
        self.frameBeforeSnap = self.frameAtDragStart;
        [snapManager snapWindow:self toSlot:slot];
        return;
    }
    NSInteger side = [self stashSideForVelocity:velocity flung:isFlungSideways];
    if (side != 0) {
        [self stashIntoLeftSide:side < 0];
        return;
    }
    [self updateOriginalFrame];
}

/// Takes a snapped window out of its half as a drag begins: back at the size
/// it had, under the finger at the same point along its title bar.
- (void)leaveSnapUnderFinger:(CGPoint)finger {
    CGRect snapped = self.view.frame;
    CGSize size = CGRectIsEmpty(self.frameBeforeSnap) ? snapped.size : self.frameBeforeSnap.size;
    [LCWindowSnapManager.shared releaseWindow:self];
    CGFloat along = snapped.size.width > 0 ? (finger.x - CGRectGetMinX(snapped)) / snapped.size.width : 0.5;
    BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
    CGFloat y = bottomWindowBar ? CGRectGetMaxY(snapped) - size.height : CGRectGetMinY(snapped);
    self.view.frame = CGRectMake(finger.x - along * size.width, y, size.width, size.height);
}

- (void)resizeWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized || self.snapSlot != LCWindowSnapSlotNone) return;
    ResizeHandleView *handle = [self.resizeHandle isKindOfClass:ResizeHandleView.class] ? (ResizeHandleView *)self.resizeHandle : nil;
    if (sender.state == UIGestureRecognizerStateBegan) {
        handle.active = YES;
    } else if (sender.state != UIGestureRecognizerStateChanged) {
        handle.active = NO;
    }
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];

    CGRect frame = self.view.frame;
    frame.size.width = MAX(50, frame.size.width + point.x);
    frame.size.height = MAX(50, frame.size.height + point.y);
    self.view.frame = frame;
    [self updateOriginalFrame];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [self raiseForTouch];
}

/// Brings the window to the front for a touch on it, on its title bar or on
/// the app itself, without bringing a tucked-away window back out: its tab's
/// own tap and drag do that.
- (void)raiseForTouch {
    if (self.view.hidden || !self.view.superview) {
        return;
    }
    // Reading the host view brings it back above the Home Screen first, in
    // case something the Home Screen drew since covered the windows.
    [MultitaskDockManager.shared windowHostingView];
    UIView *hostView = self.view.superview;
    if ([hostView isKindOfClass:VirtualWindowsHostView.class]) {
        [(VirtualWindowsHostView *)hostView raiseSubview:self.view];
    } else {
        [hostView bringSubviewToFront:self.view];
    }
}

- (void)updateVerticalConstraints {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.3 animations:^{
        BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
        // Maximized is full screen, as on iPadOS: no title bar, the app edge
        // to edge with the screen's safe area passed on to it, and the
        // window controls floating over its top-leading corner.
        BOOL hideWindowBar = self.isMaximized;
        CGFloat navBarHeight = hideWindowBar ? 0 : 44;
        self.navigationBar.alpha = hideWindowBar ? 0 : 1;
        self.navigationBar.hidden = hideWindowBar;
        // The floating controls start hidden either way.
        [self.view bringSubviewToFront:self.floatingControls];
        self.floatingControlsReveal++;
        self.floatingControls.alpha = 0;
        self.floatingControls.hidden = YES;
        
        // Update safe area insets
        if(self.isMaximized) {
            self.appSceneVC.shouldSkipDebounceOnce = YES;
            __weak typeof(self) weakSelf = self;
            [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                [weakSelf updateMaximizedFrameWithSettings:settings];
            }];
        }
        
        [NSLayoutConstraint deactivateConstraints:self.activatedVerticalConstraints];
        if(bottomWindowBar) {
            self.activatedVerticalConstraints = @[
                [self.appSceneVC.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                [self.appSceneVC.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-navBarHeight],
                [self.navigationBar.heightAnchor constraintEqualToConstant:navBarHeight]
            ];
        } else {
            self.activatedVerticalConstraints = @[
                [self.appSceneVC.view.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:navBarHeight],
                [self.appSceneVC.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
                [self.navigationBar.heightAnchor constraintEqualToConstant:navBarHeight]
            ];
        }
        [NSLayoutConstraint activateConstraints:self.activatedVerticalConstraints];
        [self updateCornerMasks];

        [self.view layoutIfNeeded];
    }];
}

#pragma mark - Snapping

- (void)didSnapToSlot:(NSInteger)slot frame:(CGRect)frame {
    if (CGRectIsEmpty(self.frameBeforeSnap)) {
        self.frameBeforeSnap = self.view.frame;
    }
    self.snapSlot = slot;
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.86 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.view.frame = frame;
        // The divider resizes a snapped window instead.
        self.resizeHandle.alpha = 0;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)didLeaveSnapRestoringFrame:(BOOL)restoresFrame {
    self.snapSlot = LCWindowSnapSlotNone;
    if (!self.isMaximized) {
        self.resizeHandle.alpha = 1;
    }
    if (!restoresFrame || CGRectIsEmpty(self.frameBeforeSnap)) {
        return;
    }
    CGRect frame = self.frameBeforeSnap;
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.86 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.view.frame = frame;
        [self.view layoutIfNeeded];
    } completion:nil];
    [self updateOriginalFrame];
}

#pragma mark - Tucking away

/// The part of the screen a window tucks against: its safe area.
- (CGRect)stashArea {
    UIView *hostView = self.view.superview;
    CGRect bounds = hostView ? hostView.bounds : self.view.window.bounds;
    return UIEdgeInsetsInsetRect(bounds, self.view.window.safeAreaInsets);
}

/// Which side to tuck the window into as it's let go: the side it's flung
/// toward, or the one it's mostly past. -1 for the left, 1 for the right, 0
/// for neither.
- (NSInteger)stashSideForVelocity:(CGPoint)velocity flung:(BOOL)flung {
    if (flung) {
        return velocity.x < 0 ? -1 : 1;
    }
    CGRect area = [self stashArea];
    CGRect frame = self.view.frame;
    if (frame.size.width <= 0) {
        return 0;
    }
    if ((CGRectGetMinX(area) - CGRectGetMinX(frame)) / frame.size.width >= LCStashOffscreenShare) {
        return -1;
    }
    if ((CGRectGetMaxX(frame) - CGRectGetMaxX(area)) / frame.size.width >= LCStashOffscreenShare) {
        return 1;
    }
    return 0;
}

/// Where a window tucked into a side sits: past it, all but the tab, at the
/// same height, kept where a thumb reaches the tab.
- (CGRect)stashedFrameIntoLeftSide:(BOOL)left fromFrame:(CGRect)frame {
    CGRect area = [self stashArea];
    frame.origin.x = left ? CGRectGetMinX(area) - frame.size.width + LCStashTabWidth : CGRectGetMaxX(area) - LCStashTabWidth;
    frame.origin.y = MAX(CGRectGetMinY(area), MIN(frame.origin.y, CGRectGetMaxY(area) - frame.size.height));
    return frame;
}

/// Where a window brought back out of a side sits: fully on screen, against
/// that side, at the same height.
- (CGRect)frameOutOfStash:(CGRect)frame {
    CGRect area = [self stashArea];
    if (frame.size.width >= area.size.width - LCStashReturnMargin * 2) {
        frame.origin.x = CGRectGetMinX(area);
    } else {
        frame.origin.x = self.stashesLeft ? CGRectGetMinX(area) + LCStashReturnMargin : CGRectGetMaxX(area) - frame.size.width - LCStashReturnMargin;
    }
    frame.origin.y = MAX(CGRectGetMinY(area), MIN(frame.origin.y, CGRectGetMaxY(area) - frame.size.height));
    return frame;
}

/// Tucks the window into a side, as macOS tucks away Picture in Picture.
- (void)stashIntoLeftSide:(BOOL)left {
    self.isStashed = YES;
    self.stashesLeft = left;
    [self showStashTab];
    CGRect frame = [self stashedFrameIntoLeftSide:left fromFrame:self.view.frame];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.view.frame = frame;
        self.stashTab.alpha = 1;
        // The tab covers the corner the handle would be in.
        self.resizeHandle.alpha = 0;
    } completion:nil];
}

- (void)unstashAnimated:(BOOL)animated {
    if (!self.isStashed) {
        return;
    }
    self.isStashed = NO;
    CGRect frame = [self frameOutOfStash:self.view.frame];
    UIView *tab = self.stashTab;
    void (^changes)(void) = ^{
        self.view.frame = frame;
        tab.alpha = 0;
        self.resizeHandle.alpha = self.isMaximized ? 0 : 1;
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!self.isStashed) {
            [tab removeFromSuperview];
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:changes completion:completion];
    } else {
        changes();
        completion(YES);
    }
    [self updateOriginalFrame];
}

- (void)restash {
    if (self.isStashed) {
        self.view.frame = [self stashedFrameIntoLeftSide:self.stashesLeft fromFrame:self.view.frame];
    }
}

/// A drag on the tab pulls the window out wherever the finger takes it.
- (void)leaveStashForDrag {
    self.isStashed = NO;
    UIView *tab = self.stashTab;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        tab.alpha = 0;
        self.resizeHandle.alpha = 1;
    } completion:^(BOOL finished) {
        if (!self.isStashed) {
            [tab removeFromSuperview];
        }
    }];
}

- (void)stashTabTapped {
    [self unstashAnimated:YES];
}

/// The tab over the sliver of a tucked-away window left on screen: glass,
/// with a chevron pointing back onto the screen.
- (void)showStashTab {
    if (!self.stashTab) {
        UIVisualEffectView *tab = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
        tab.clipsToBounds = YES;
        tab.layer.cornerRadius = LCWindowCornerRadius;
        tab.layer.cornerCurve = kCACornerCurveContinuous;
        tab.alpha = 0;

        UIImageView *chevron = [[UIImageView alloc] init];
        chevron.translatesAutoresizingMaskIntoConstraints = NO;
        chevron.tintColor = [UIColor colorWithWhite:1.0 alpha:0.9];
        chevron.tag = 1;
        [tab.contentView addSubview:chevron];
        [NSLayoutConstraint activateConstraints:@[
            [chevron.centerXAnchor constraintEqualToAnchor:tab.contentView.centerXAnchor],
            [chevron.centerYAnchor constraintEqualToAnchor:tab.contentView.centerYAnchor],
        ]];

        [tab addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(stashTabTapped)]];
        UIPanGestureRecognizer *pull = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
        pull.maximumNumberOfTouches = 1;
        [tab addGestureRecognizer:pull];

        tab.isAccessibilityElement = YES;
        tab.accessibilityTraits = UIAccessibilityTraitButton;
        self.stashTab = tab;
    }
    UIVisualEffectView *tab = self.stashTab;
    BOOL left = self.stashesLeft;
    CGRect bounds = self.view.bounds;
    // Over the part left on screen, rounded on that side as the window is.
    tab.frame = left ? CGRectMake(bounds.size.width - LCStashTabWidth, 0, LCStashTabWidth, bounds.size.height) : CGRectMake(0, 0, LCStashTabWidth, bounds.size.height);
    tab.autoresizingMask = UIViewAutoresizingFlexibleHeight | (left ? UIViewAutoresizingFlexibleLeftMargin : UIViewAutoresizingFlexibleRightMargin);
    tab.layer.maskedCorners = left ? (kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner) : (kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner);
    UIImageView *chevron = (UIImageView *)[tab.contentView viewWithTag:1];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    chevron.image = [[UIImage systemImageNamed:left ? @"chevron.compact.right" : @"chevron.compact.left"] imageWithConfiguration:configuration];
    tab.accessibilityLabel = [NSString stringWithFormat:@"Show %@", self.title ?: @"Window"];
    if (tab.superview != self.view) {
        [self.view addSubview:tab];
    }
    [self.view bringSubviewToFront:tab];
}

#pragma mark - Floating controls

/// Shows the floating window controls, then hides them again after
/// `duration` seconds, unless another reveal came in meanwhile.
- (void)revealFloatingControlsFor:(NSTimeInterval)duration {
    NSUInteger reveal = ++self.floatingControlsReveal;
    self.floatingControls.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.floatingControls.alpha = 1;
    }];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self || reveal != self.floatingControlsReveal || !self.isMaximized) return;
        [UIView animateWithDuration:0.3 animations:^{
            self.floatingControls.alpha = 0;
        } completion:^(BOOL finished) {
            if (reveal == self.floatingControlsReveal && self.floatingControls.alpha == 0) {
                self.floatingControls.hidden = YES;
            }
        }];
    });
}

- (void)revealWindowControls {
    if (!self.isMaximized) return;
    [self revealFloatingControlsFor:4.0];
}

- (BOOL)revealWindowControlsForStatusBarTap:(UIAction *)action {
    if (!self.isMaximized) return NO;
    // UIStatusBarTapAction says where along the bar the tap was; a tap on
    // the leading half, the clock's, shows the controls, and one on the
    // other half still scrolls the app to the top. Without a position, any
    // tap shows them.
    SEL xPosition = NSSelectorFromString(@"xPosition");
    if ([action respondsToSelector:xPosition]) {
        CGFloat x = [[action valueForKey:@"xPosition"] doubleValue];
        CGFloat width = self.view.bounds.size.width;
        BOOL leading = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? x > width / 2 : x < width / 2;
        if (!leading) return NO;
    }
    [self revealFloatingControlsFor:4.0];
    return YES;
}

#pragma mark - Window style

/// Rounds the window's corners and gives it its shadow: smaller corners and
/// no shadow while it fills the screen, as an iPadOS window has.
- (void)applyWindowStyleMaximized:(BOOL)maximized {
    CGFloat radius = maximized ? LCMaximizedWindowCornerRadius : LCWindowCornerRadius;
    self.view.layer.cornerRadius = radius;
    self.view.layer.shadowOpacity = maximized ? 0 : LCWindowShadowOpacity;
    if ([self.resizeHandle isKindOfClass:ResizeHandleView.class]) {
        ((ResizeHandleView *)self.resizeHandle).windowCornerRadius = radius;
    }
    [self updateCornerMasks];
    [self.view setNeedsLayout];
}

/// Clips the title bar and the app to the window's rounded corners: the bar
/// takes the corners on its side, the app the others, or all four when the
/// bar is hidden. The window view itself can't clip, or it would cut off its
/// own shadow.
- (void)updateCornerMasks {
    CGFloat radius = self.view.layer.cornerRadius;
    CACornerMask top = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    CACornerMask bottom = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
    CACornerMask barCorners = bottomWindowBar ? bottom : top;
    CACornerMask appCorners = self.navigationBar.hidden ? (top | bottom) : (bottomWindowBar ? top : bottom);
    for (UIView *view in @[self.navigationBar, self.appSceneVC.view]) {
        view.layer.cornerRadius = radius;
        view.layer.cornerCurve = kCACornerCurveContinuous;
        view.layer.masksToBounds = YES;
    }
    self.navigationBar.layer.maskedCorners = barCorners;
    self.appSceneVC.view.layer.maskedCorners = appCorners;
}

/// The close, minimize and maximize dots, in a row for the title bar.
- (UIView *)windowControlsView {
    UIButton *close = [self windowControlWithColor:UIColor.systemRedColor symbol:@"xmark" action:@selector(closeWindow)];
    close.accessibilityLabel = @"Close";
    UIButton *minimize = [self windowControlWithColor:UIColor.systemYellowColor symbol:@"minus" action:@selector(minimizeWindow)];
    minimize.accessibilityLabel = @"Minimize";
    UIButton *maximize = [self windowControlWithColor:UIColor.systemGreenColor symbol:nil action:@selector(maximizeWindow)];
    if (!self.maximizeControls) {
        self.maximizeControls = [NSMutableArray array];
    }
    [self.maximizeControls addObject:maximize];
    [self updateMaximizeControl];

    LCWindowControlsView *controls = [[LCWindowControlsView alloc] initWithArrangedSubviews:@[close, minimize, maximize]];
    controls.axis = UILayoutConstraintAxisHorizontal;
    controls.spacing = 0;
    controls.frame = CGRectMake(0, 0, LCWindowControlSize.width * 3, LCWindowControlSize.height);
    return controls;
}

/// One of the dots: a colored circle with a small dark glyph, in a touch
/// area larger than it.
- (UIButton *)windowControlWithColor:(UIColor *)color symbol:(NSString *)symbol action:(SEL)action {
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets = NSDirectionalEdgeInsetsZero;
    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:LCWindowControlSize.width].active = YES;
    [button.heightAnchor constraintEqualToConstant:LCWindowControlSize.height].active = YES;

    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.userInteractionEnabled = NO;
    dot.backgroundColor = color;
    dot.layer.cornerRadius = LCWindowControlDiameter / 2;
    dot.tag = 1;
    [button addSubview:dot];

    UIImageView *glyph = [[UIImageView alloc] init];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.contentMode = UIViewContentModeCenter;
    glyph.tintColor = [UIColor colorWithWhite:0 alpha:0.55];
    glyph.tag = 2;
    [dot addSubview:glyph];
    [self setGlyph:symbol ofWindowControl:button];

    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:LCWindowControlDiameter],
        [dot.heightAnchor constraintEqualToConstant:LCWindowControlDiameter],
        [dot.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [glyph.centerXAnchor constraintEqualToAnchor:dot.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:dot.centerYAnchor],
    ]];
    return button;
}

- (void)setGlyph:(NSString *)symbol ofWindowControl:(UIButton *)button {
    UIImageView *glyph = (UIImageView *)[[button viewWithTag:1] viewWithTag:2];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:7 weight:UIImageSymbolWeightBlack];
    glyph.image = symbol ? [[UIImage systemImageNamed:symbol] imageWithConfiguration:configuration] : nil;
}

/// The green dot's glyph and label follow whether the window fills the screen.
- (void)updateMaximizeControl {
    NSString *symbol = self.isMaximized ? @"arrow.down.right.and.arrow.up.left" : @"arrow.up.left.and.arrow.down.right";
    for (UIButton *control in self.maximizeControls) {
        [self setGlyph:symbol ofWindowControl:control];
        control.accessibilityLabel = self.isMaximized ? @"Exit Full Screen" : @"Full Screen";
    }
}

- (UIEdgeInsets)updateMaximizedSafeAreaWithSettings:(UIMutableApplicationSceneSettings *)settings {
    BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    if(self.navigationBar.hidden) {
        settings.peripheryInsets = safeAreaInsets;
        safeAreaInsets = UIEdgeInsetsZero;
    } else if(bottomWindowBar) {
        // allow the control bar to overlap the bottom safe area
        safeAreaInsets.bottom = 0;
        settings.peripheryInsets = safeAreaInsets;
        safeAreaInsets.top = safeAreaInsets.left = safeAreaInsets.right = 0;
    } else {
        settings.peripheryInsets = UIEdgeInsetsMake(0, safeAreaInsets.left, safeAreaInsets.bottom, safeAreaInsets.right);
        safeAreaInsets.bottom = safeAreaInsets.left = safeAreaInsets.right = 0;
    }
    
    // scale peripheryInsets to match the scale ratio
    settings.peripheryInsets = UIEdgeInsetsMake(settings.peripheryInsets.top/_scaleRatio, settings.peripheryInsets.left/_scaleRatio, settings.peripheryInsets.bottom/_scaleRatio, settings.peripheryInsets.right/_scaleRatio);
    if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        UIInterfaceOrientation currentOrientation = UIApp.statusBarOrientation;
        if(UIInterfaceOrientationIsLandscape(currentOrientation)) {
            safeAreaInsets.top = 0;
        }
        settings.safeAreaInsetsPortrait = LCUIEdgeInsetsRotateToOrientation(settings.peripheryInsets, currentOrientation);

    } else {
        settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.top, settings.peripheryInsets.left, settings.peripheryInsets.bottom, settings.peripheryInsets.right);
    }
    
    safeAreaInsets.bottom = 0;
    return safeAreaInsets;
}

- (void)updateMaximizedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, [self updateMaximizedSafeAreaWithSettings:settings]);
    self.view.frame = maxFrame;
}

- (void)updateWindowedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, safeAreaInsets);
    settings.peripheryInsets = UIEdgeInsetsZero;
    settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;

    // A window being dragged goes where the finger takes it, however tall,
    // rather than back on screen.
    if (self.isBeingDragged) {
        return;
    }

    // A snapped window keeps to its half, and a tucked-away one to its side.
    CGRect placed = CGRectNull;
    if (self.snapSlot != LCWindowSnapSlotNone) {
        placed = [LCWindowSnapManager.shared frameForWindow:self];
    } else if (self.isStashed) {
        placed = [self stashedFrameIntoLeftSide:self.stashesLeft fromFrame:self.view.frame];
    }
    if (!CGRectIsNull(placed)) {
        [UIView animateWithDuration:0.3 animations:^{
            self.view.frame = placed;
        }];
        return;
    }
    
    CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
    CGPoint center = self.view.center;
    CGRect frame = CGRectZero;
    frame.size.width = MIN(newFrame.size.width, maxFrame.size.width);
    frame.size.height = MIN(newFrame.size.height, maxFrame.size.height);
    CGFloat oobOffset = MAX(30, frame.size.width - 30);
    frame.origin.x = MAX(maxFrame.origin.x - oobOffset, MIN(CGRectGetMaxX(maxFrame) - frame.size.width + oobOffset, center.x - frame.size.width / 2));
    frame.origin.y = MAX(maxFrame.origin.y, MIN(center.y - frame.size.height / 2, CGRectGetMaxY(maxFrame) - frame.size.height));
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = frame;
    }];
}

- (void)updateOriginalFrame {
    // A window in a half or tucked into a side keeps where it last floated.
    if(_isMaximized || self.snapSlot != LCWindowSnapSlotNone || self.isStashed) return;
    [self updateOriginalFrameFromFrame:self.view.frame];
}

- (void)updateOriginalFrameFromFrame:(CGRect)frame {
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
    // save origin as normalized coordinates
    self.originalFrame = CGRectMake(frame.origin.x / maxFrame.size.width, frame.origin.y / maxFrame.size.height, frame.size.width, frame.size.height);
}

@end

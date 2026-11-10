//
//  ResizeHandleView.m
//  LiveContainer
//
//  Created by Duy Tran on 2/6/25.
//
#import "ResizeHandleView.h"
#include <dlfcn.h>

/// The arc's width where it's drawn without the Home indicator's material.
static const CGFloat ResizeGrabberLineWidth = 5.0;
/// MTLumaDodgePillView's styles: thin, the grabber's to begin with, then
/// gray, black or white as the luminance behind it becomes known.
static const NSInteger ResizeGrabberStyleThin = 1;
static const NSInteger ResizeGrabberStyleGray = 2;
static const NSInteger ResizeGrabberStyleBlack = 3;
static const NSInteger ResizeGrabberStyleWhite = 4;
/// MTLumaDodgePillView's backgroundLuminance values.
static const NSInteger ResizeGrabberLuminanceDark = 1;
static const NSInteger ResizeGrabberLuminanceLight = 2;
/// MTLumaDodgeGraphicsQuality's low quality color matrix, which SpringBoard
/// draws its grabbers with.
static const NSInteger ResizeGrabberGraphicsQualityLow = -100;

/// MaterialKit's luma-dodging pill, which the Home indicator and iPadOS's
/// resize grabber are drawn in.
@protocol LCLumaDodgePill
- (instancetype)initWithFrame:(CGRect)frame settings:(id)settings graphicsQuality:(NSInteger)graphicsQuality;
- (void)setStyle:(NSInteger)style;
- (void)setCustomPillShapePath:(UIBezierPath *)path animated:(BOOL)animated;
- (void)setBackgroundLumninanceObserver:(id)observer;
- (NSInteger)backgroundLuminance;
@end

@protocol LCLumaDodgePillSettings
+ (id)sharedInstance;
@end

/// MTLumaDodgePillView, where this iOS has it with a custom shape.
static Class ResizeGrabberPillClass(void) {
    static Class pillClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen("/System/Library/PrivateFrameworks/MaterialKit.framework/MaterialKit", RTLD_LAZY);
        Class candidate = NSClassFromString(@"MTLumaDodgePillView");
        Class settings = NSClassFromString(@"MTLumaDodgePillSettings");
        if ([candidate isSubclassOfClass:UIView.class]
            && [settings respondsToSelector:@selector(sharedInstance)]
            && [candidate instancesRespondToSelector:@selector(initWithFrame:settings:graphicsQuality:)]
            && [candidate instancesRespondToSelector:@selector(setStyle:)]
            && [candidate instancesRespondToSelector:@selector(setCustomPillShapePath:animated:)]) {
            pillClass = candidate;
        }
    });
    return pillClass;
}

@implementation ResizeHandleView {
    UIView<LCLumaDodgePill> *_pill;
    CAShapeLayer *_arcLayer;
    /// The side of the square the arc is drawn in, whose bottom-right is
    /// the window's corner.
    CGFloat _side;
}

/// SpringBoard's grabber for a window corner of `radius`, as
/// SBAppResizeGrabberView works it out: the window's corner circle 6 points
/// inside its edge, 30 points of it centered on the diagonal, in a square
/// 20 points plus the corner's inset along the diagonal on each side.
+ (UIBezierPath *)grabberPathForCornerRadius:(CGFloat)radius side:(CGFloat *)side {
    CGFloat corner = MAX(radius, 18.0);
    CGFloat curve = MAX(corner - 6.0, 6.0);
    CGFloat inset = round(corner - corner * M_SQRT1_2);
    CGFloat circumference = round(2.0 * M_PI * curve);
    CGFloat length = MIN(30.0, circumference / 4.0);
    CGFloat sweep = 2.0 * M_PI * length / circumference;
    // The corner circle's center, in the square: 6 points and the curve in
    // from the window's corner.
    CGFloat center = 20.0 + inset - 6.0 - curve;
    CGFloat start = M_PI_4 + sweep / 2.0;
    CGFloat end = M_PI_4 - sweep / 2.0;
    CGPoint first = CGPointMake(center + curve * cos(start), center + curve * sin(start));
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:first];
    [path addLineToPoint:first];
    [path addArcWithCenter:CGPointMake(center, center) radius:curve startAngle:start endAngle:end clockwise:NO];
    [path addLineToPoint:CGPointMake(center + curve * cos(end), center + curve * sin(end))];
    *side = 20.0 + inset;
    return path;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    _windowCornerRadius = 32.0;
    Class pillClass = ResizeGrabberPillClass();
    if (pillClass) {
        id settings = [NSClassFromString(@"MTLumaDodgePillSettings") sharedInstance];
        _pill = (UIView<LCLumaDodgePill> *)[(id<LCLumaDodgePill>)[pillClass alloc] initWithFrame:CGRectZero settings:settings graphicsQuality:ResizeGrabberGraphicsQualityLow];
        [_pill setStyle:ResizeGrabberStyleThin];
        if ([_pill respondsToSelector:@selector(setBackgroundLumninanceObserver:)]) {
            [_pill setBackgroundLumninanceObserver:self];
        }
        _pill.userInteractionEnabled = NO;
        [self addSubview:_pill];
    } else {
        // Without the material, a gray stroke along the same curve.
        _arcLayer = [CAShapeLayer layer];
        _arcLayer.fillColor = nil;
        _arcLayer.lineWidth = ResizeGrabberLineWidth;
        _arcLayer.lineCap = kCALineCapRound;
        [self.layer addSublayer:_arcLayer];
        [self updateArcColor];
        if (@available(iOS 17.0, *)) {
            [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateArcColor)];
        }
    }
    [self updateGrabberPath];
    self.accessibilityLabel = @"Resize";
    return self;
}

- (void)setWindowCornerRadius:(CGFloat)windowCornerRadius {
    if (_windowCornerRadius == windowCornerRadius) {
        return;
    }
    _windowCornerRadius = windowCornerRadius;
    [self updateGrabberPath];
}

- (void)updateGrabberPath {
    CGFloat side = 0;
    UIBezierPath *path = [ResizeHandleView grabberPathForCornerRadius:self.windowCornerRadius side:&side];
    _side = side;
    [_pill setCustomPillShapePath:path animated:NO];
    _arcLayer.path = path.CGPath;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect square = CGRectMake(CGRectGetMaxX(self.bounds) - _side, CGRectGetMaxY(self.bounds) - _side, _side, _side);
    _pill.frame = square;
    _arcLayer.frame = square;
}

/// As SpringBoard's grabber: white over dark, black over light, gray while
/// it can't tell.
- (void)lumaDodgePillDidDetectBackgroundLuminanceChange:(UIView<LCLumaDodgePill> *)pill {
    NSInteger luminance = [pill backgroundLuminance];
    [pill setStyle:luminance == ResizeGrabberLuminanceLight ? ResizeGrabberStyleBlack : luminance == ResizeGrabberLuminanceDark ? ResizeGrabberStyleWhite : ResizeGrabberStyleGray];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    // Before iOS 17, which has trait change registration instead.
    if (@available(iOS 17.0, *)) {
        return;
    }
    [self updateArcColor];
}

- (void)updateArcColor {
    _arcLayer.strokeColor = [UIColor.secondaryLabelColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

@end

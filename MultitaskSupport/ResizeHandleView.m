//
//  ResizeHandleView.m
//  LiveContainer
//
//  Created by Duy Tran on 2/6/25.
//
#import "ResizeHandleView.h"

/// How far inside the window's edge the arc runs.
static const CGFloat ResizeHandleInset = 6.0;
static const CGFloat ResizeHandleLineWidth = 5.0;
/// The arc's width while the window is being resized.
static const CGFloat ResizeHandleActiveLineWidth = 7.0;
/// How much of the corner's quarter turn the arc covers, centered on it.
static const CGFloat ResizeHandleSweep = M_PI / 3.0;

@implementation ResizeHandleView {
    CAShapeLayer *_arcLayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    _windowCornerRadius = 22.0;
    _arcLayer = [CAShapeLayer layer];
    _arcLayer.fillColor = nil;
    _arcLayer.lineWidth = ResizeHandleLineWidth;
    _arcLayer.lineCap = kCALineCapRound;
    [self.layer addSublayer:_arcLayer];
    [self updateArcColor];
    if (@available(iOS 17.0, *)) {
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateArcColor)];
    }
    self.accessibilityLabel = @"Resize";
    return self;
}

- (void)setActive:(BOOL)active {
    if (_active == active) {
        return;
    }
    _active = active;
    // A sublayer's width and color animate on their own.
    _arcLayer.lineWidth = active ? ResizeHandleActiveLineWidth : ResizeHandleLineWidth;
    [self updateArcColor];
}

- (void)setWindowCornerRadius:(CGFloat)windowCornerRadius {
    _windowCornerRadius = windowCornerRadius;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _arcLayer.frame = self.bounds;
    // The window's corner is a quarter circle centered this far in from the
    // bottom-right; the arc runs along it, a little inside the edge.
    CGFloat radius = MAX(self.windowCornerRadius, ResizeHandleInset * 2);
    CGPoint center = CGPointMake(CGRectGetMaxX(self.bounds) - radius, CGRectGetMaxY(self.bounds) - radius);
    CGFloat middle = M_PI_4;
    UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:center
                                                       radius:radius - ResizeHandleInset
                                                   startAngle:middle - ResizeHandleSweep / 2
                                                     endAngle:middle + ResizeHandleSweep / 2
                                                    clockwise:YES];
    _arcLayer.path = arc.CGPath;
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
    // Readable over whatever the app draws in that corner, light or dark,
    // and stronger while the window is being resized.
    UIColor *color = self.active ? UIColor.labelColor : UIColor.secondaryLabelColor;
    _arcLayer.strokeColor = [color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

@end

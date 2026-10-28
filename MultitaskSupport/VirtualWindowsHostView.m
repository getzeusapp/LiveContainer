//
//  VirtualWindowsHostView.m
//  LiveContainer
//
//  Created by Duy Tran on 22/2/26.
//
#import "DecoratedAppSceneViewController.h"
#import "VirtualWindowsHostView.h"
#import "LCWindowSnapManager.h"

@implementation VirtualWindowsHostView {
    /// The size the windows were last laid out for.
    CGSize _laidOutSize;
}
- (instancetype)init {
    // MultitaskDockManager sizes it to the main window's root view when it puts
    // it there, above the Home Screen. Any connected scene could come first
    // here, which on iPad may not be the main window's, or may have no window
    // at all.
    self = [super initWithFrame:CGRectZero];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.shouldForwardTapAction = YES;
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    // A new size, as when the screen rotates, lays the snapped windows out
    // again and keeps tucked-away ones against their sides.
    if (CGSizeEqualToSize(self.bounds.size, _laidOutSize)) {
        return;
    }
    _laidOutSize = self.bounds.size;
    [LCWindowSnapManager.shared layoutInView:self];
    for (UIView *view in self.subviews) {
        DecoratedAppSceneViewController *window = (id)view._viewDelegate;
        if ([window isKindOfClass:DecoratedAppSceneViewController.class] && window.isStashed) {
            [window restash];
        }
    }
}

- (void)bringSubviewToFront:(UIView *)view {
    [self raiseSubview:view];
    // A window brought forward from the multitask dock comes back out of the
    // side it's tucked into.
    DecoratedAppSceneViewController *window = (id)view._viewDelegate;
    if ([window isKindOfClass:DecoratedAppSceneViewController.class] && window.isStashed) {
        [window unstashAnimated:YES];
    }
}

- (void)raiseSubview:(UIView *)view {
    [super bringSubviewToFront:view];
    [LCWindowSnapManager.shared keepDividerOnTopInView:self];
}

/// A window that opens goes under the divider between snapped windows.
- (void)didAddSubview:(UIView *)subview {
    [super didAddSubview:subview];
    [LCWindowSnapManager.shared keepDividerOnTopInView:self];
}

- (BOOL)handleStatusBarTapAction:(UIAction *)action {
    if(!self.shouldForwardTapAction) return NO;
    // grab the frontmost app window, if it's visible pass this event to it
    UIView *frontmostView = self.subviews.lastObject;
    if(!frontmostView.hidden) {
        DecoratedAppSceneViewController *decoratedVC = (id)frontmostView._viewDelegate;
        if(![decoratedVC revealWindowControlsForStatusBarTap:action]) {
            [decoratedVC.appSceneVC handleStatusBarTapAction:action];
        }
    }
    return !frontmostView.hidden;
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView* hitView = [super hitTest:point withEvent:event];
    if(hitView == self) {
        self.shouldForwardTapAction = NO;
        return nil;
    } else {
        self.shouldForwardTapAction = YES;
        return hitView;
    }
}
@end

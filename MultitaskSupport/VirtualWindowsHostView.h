//
//  VirtualWindowsHostView.h
//  LiveContainer
//
//  Created by Duy Tran on 22/2/26.
//
@import UIKit;

API_AVAILABLE(ios(16.0))
@interface VirtualWindowsHostView: UIView
@property(nonatomic) BOOL shouldForwardTapAction;
- (BOOL)handleStatusBarTapAction:(UIAction *)action;
/// Brings a window to the front for a touch on it. Unlike
/// bringSubviewToFront:, which the multitask dock uses, it leaves a
/// tucked-away window where it is.
- (void)raiseSubview:(UIView *)view;
@end

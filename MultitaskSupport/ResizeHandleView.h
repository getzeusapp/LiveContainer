//
//  ResizeHandleView.h
//  LiveContainer
//
//  Created by Duy Tran on 2/6/25.
//
#import <UIKit/UIKit.h>

/// The grab area in a window's bottom-right corner, drawn as iPadOS 26.5
/// draws it (SpringBoard's SBAppResizeGrabberView): a short, thick arc along
/// the window's rounded corner, in the material the Home indicator uses.
@interface ResizeHandleView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
/// The window's corner radius, which the arc follows.
@property(nonatomic) CGFloat windowCornerRadius;
@end

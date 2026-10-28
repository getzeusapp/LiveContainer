//
//  ResizeHandleView.h
//  LiveContainer
//
//  Created by Duy Tran on 2/6/25.
//
#import <UIKit/UIKit.h>

/// The grab area in a window's bottom-right corner, drawn as iPadOS draws
/// it: a short arc that follows the window's rounded corner.
@interface ResizeHandleView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
/// The window's corner radius, which the arc follows.
@property(nonatomic) CGFloat windowCornerRadius;
/// Whether the window is being resized, which draws the arc bolder.
@property(nonatomic, getter=isActive) BOOL active;
@end

//
//  LyzZMetaxParaboloidButton.h
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/6/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    LyzZMetaxParaboloidButtonNormalStyle = 0,
    LyzZMetaxParaboloidButtonListenningStyle = 1,
    LyzZMetaxParaboloidButtonLoadingStyle = 2
} LyzZMetaxParaboloidButtonStyle;

@interface LyzZMetaxParaboloidButton : UIControl

/// 帧率，每秒的帧数
@property (nonatomic, assign) NSInteger framesPerSecond;

/// 设置是否暂停渲染
@property (nonatomic, getter=isPaused) BOOL paused;

/*
 * @brief 设置各个面片各个轴的旋转速度;
 * @param index 面片索引。如果index超出面片个数，则默认设置所有面片。0 设置所有面片;
 * @param x 设置x轴的旋转速度;
 * @param y 设置y轴的旋转速度;
 * @param z 设置z轴的旋转速度;
 */
- (void)setSpinningSpeed:(NSUInteger)index x:(CGFloat)x y:(CGFloat)y z:(CGFloat)z;

/*
 * @brief 设置各个面片的颜色;
 * @param colors 数组，目前是3个面片。因此数组中的元素是NSNumber包装了NSUInteger的对象;
 */
- (void)setCurvedSurfaceColor:(NSArray <NSNumber *>*)colors;

/*
 * @brief 设置按钮当前样式。目前包含有三种状态：正常态、聆听态和加载态;
 *             局限于动画的切换，因此不支持任意状态的切换。目前支持的状态变化有：
 *              normal -> listenning
 *              listenning |-> normal
 *                                 |-> loading
 *              loading -> normal
 * @param style 样式;
 * @return 不符合上述规则时返回NO，出于切换过程中时返回NO；
 */
- (BOOL)setCurrentStyle:(LyzZMetaxParaboloidButtonStyle)style;

- (void)stopRenderLoop;
@end

NS_ASSUME_NONNULL_END

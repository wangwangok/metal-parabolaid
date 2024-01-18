//
//  LyzZMetaxParaboloidPipeline.h
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/6/9.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "LyzZMetaxParaboloidAnimationStrategy.h"
#import "LyzZMetaxParaboloidTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// 投影矩阵近平面
extern float kLyzZMetaxParaboloidPipelineNearValue;

/// 投影矩阵远平面
extern float kLyzZMetaxParaboloidPipelineFarValue;

@protocol LyzZMetaxParaboloidPipelineDelegate <NSObject>
@optional
/// 向外部获取当前策略
- (LyzZMetaxParaboloidAnimationStrategy *)currentAnimationStrategy;

/// 流水线内部更改策略
- (void)pipelineStageDidCompleteShouldChangeStrategy:(LyzZMetaxParaboloidPipeline *)pipeline;
@end

@interface LyzZMetaxParaboloidPipeline : NSObject
@property (nonatomic, nullable, weak) id<LyzZMetaxParaboloidPipelineDelegate> delegate;
/// 旋转角度，x：x轴旋转角度；y：y轴旋转角度；z：z轴旋转角度；
@property (nonatomic, assign) vector_float3 rotateValue;
/// 各个轴的旋转速度
@property (nonatomic, assign) vector_float3 angularVelocity;
/// 平移距离，x：x轴平移距离；y：y轴平移距离；z：z轴平移距离
@property (nonatomic, assign) vector_float3 translateValue;
/// 各个轴的平移速度
@property (nonatomic, assign) vector_float3 translationVelocity;
/// 帧率
@property (nonatomic, assign) NSInteger framesPerSecond;
/// 当前索引
@property (nonatomic, assign) NSUInteger currentIndex;

@property (nonatomic, copy) simd_float4x4(^modelTransformBlock)(vector_float3 rotate, vector_float3 translate);

/// 模型矩阵（平移、旋转、缩放等等）
- (simd_float4x4)modelMatrix;

/// 视图矩阵（设置视点。即up、center和eye）
- (simd_float4x4)viewMatrix;

/// 投影矩阵
- (simd_float4x4)projectionMatrix:(CGSize)drawSize;

/*
 * @brief 构建全局数据;
 * @param bufferPtr buffer指针;
 * @param drawSize 当前绘制区域;
 * @return 是否构建成功；
 */
- (BOOL)buildUniformsBuffer:(LyzZVzxParaboloidUniforms *)bufferPtr drawableSize:(CGSize)drawSize;

/*
 * @brief 计算绘制所需的模型变换矩阵。即旋转、平移和缩放等等;
 * @param duration 变化所需时长;
 */
- (void)pipelineModelMatrix:(NSTimeInterval)duration;
@end

NS_ASSUME_NONNULL_END

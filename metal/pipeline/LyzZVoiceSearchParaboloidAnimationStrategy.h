//
//  LyzZMetaxParaboloidView.h
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/5/31.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN
@class LyzZMetaxParaboloidPipeline;
#pragma mark - LyzZMetaxParaboloidAnimationStrategy
/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidAnimationStrategy ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidAnimationStrategy : NSObject {
@public
    vector_float3 _angular[3];
    vector_float3 _translates[3];
    float _timingControlPoints[4];
    simd_float4x4 modelMatrix[3]; /// 当前模型矩阵
    simd_float4x4 startMatrix[3]; /// 初始状态模型矩阵
    simd_float4x4 prevmMatrix[3]; /// 上一个状态的模型矩阵
    simd_float4x4 nextmMatrix[3]; /// 下一个状态的模型矩阵
    simd_float4x4 viewMatrix; /// 当前视图矩阵
}

@property (nonatomic, weak) LyzZMetaxParaboloidAnimationStrategy *next;
@property (nonatomic, weak) LyzZMetaxParaboloidAnimationStrategy *prev;
@property (nonatomic, strong) CAMediaTimingFunction *timingFunction;
@property (nonatomic, assign) float timeDuration;
@property (nonatomic, assign) NSInteger fps;
@property (nonatomic, assign) NSUInteger type;

/// 加载态所需数据
@property (nonatomic, assign) float zProgress;
@property (nonatomic, assign) uint lhs;
@property (nonatomic, assign) uint rhs;

- (void)resetToInitial;

- (instancetype)initWithFPS:(NSUInteger)fps;

- (void)setPipelinesAngular:(vector_float3 *)angular
                  translate:(vector_float3 *)translates
                     length:(NSUInteger)length;

/// 初始值
- (vector_float3)rotateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline;
- (vector_float3)translateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline;

/// 变化值
- (vector_float3)rotateStride:(NSTimeInterval)frameDuration pipeline:(LyzZMetaxParaboloidPipeline *)pipeline;
- (vector_float3)translateStride:(NSTimeInterval)frameDuration pipeline:(LyzZMetaxParaboloidPipeline *)pipeline;

/// 当前animation完成
- (BOOL)framesCompleteWith:(LyzZMetaxParaboloidPipeline *)pipeline;
/// 模型变换矩阵
- (simd_float4x4)modelMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline;
/// 视图变换矩阵
- (simd_float4x4)viewMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline;

/// 取消动效
- (void)cancel;
@end

/// 静止态
@interface LyzZMetaxParaboloidNormalAnimationStrategy : LyzZMetaxParaboloidAnimationStrategy
@end
/// 聆听态
@interface LyzZMetaxParaboloidListenningAnimationStrategy : LyzZMetaxParaboloidAnimationStrategy
@end
/// 加载态
@interface LyzZMetaxParaboloidLoadingAnimationStrategy : LyzZMetaxParaboloidAnimationStrategy
@end
/// 过渡态
@interface LyzZMetaxParaboloidTransitionAnimationStrategy : LyzZMetaxParaboloidAnimationStrategy
@end

NS_ASSUME_NONNULL_END

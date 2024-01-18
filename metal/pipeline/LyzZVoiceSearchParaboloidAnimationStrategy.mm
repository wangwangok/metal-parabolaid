//
//  LyzZMetaxParaboloidView.m
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/5/31.
//

#import "LyzZMetaxParaboloidAnimationStrategy.h"
#import "LyzZMetaxParaboloidMath.h"
#import "LyzZMetaxParaboloidPipeline.h"
#include "LyzZMetaxParaboloidTypes.h"

/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidAnimationStrategy ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidAnimationStrategy ()

@end
@implementation LyzZMetaxParaboloidAnimationStrategy
- (instancetype)initWithFPS:(NSUInteger)fps {
    if (self = [super init]) {
        self.zProgress = 0.0f;
        self.rhs = 0;
        self.lhs = 0;
        self.fps = fps;
        [self resetToInitial];
        bzero(startMatrix, 3 * sizeof(simd_float4x4));
        bzero(modelMatrix, 3 * sizeof(simd_float4x4));
        bzero(prevmMatrix, 3 * sizeof(simd_float4x4));
        bzero(nextmMatrix, 3 * sizeof(simd_float4x4));
        simd::float4x4 vMatrix = lyzzvs::identity();
        /// 将物体放在-z轴的方向，那么我们眼睛就是从正z轴看去。这里使用的是右手坐标系，正z轴在屏幕外
        /// vMatrix = lyzzvs::translate(vMatrix, 0.0f, 0.0f, -2.0f);
        viewMatrix = lyzzvs::matrixSetLookAt(
                                         0.0f, 0.0f, 100.0f, /// eye
                                         0.0f, 0.0f, 0.0f, /// center
                                         0.0f, 1.0f, 0.0f /// up
                                         ) * vMatrix;
    }
    return self;
}

- (void)resetToInitial {
    self.zProgress = 0.0f;
    self.rhs = 0;
    self.lhs = 0;
    bzero(_angular, 3 * sizeof(vector_float3));
    bzero(_translates, 3 * sizeof(vector_float3));
    bzero(_timingControlPoints, 4 * sizeof(float));
}

- (void)setPipelinesAngular:(vector_float3 *)angular
                  translate:(vector_float3 *)translates
                     length:(NSUInteger)length {
    if (length != 3) {
        return;
    }
    
    if (angular != nil) {
        _angular[0] = *(angular);
        _angular[1] = *(angular+1);
        _angular[2] = *(angular+2);
    }
    
    if (translates != nil) {
        _translates[0] = *(translates);
        _translates[1] = *(translates+1);
        _translates[2] = *(translates+2);
    }
}

- (void)setTimingFunction:(CAMediaTimingFunction *)timingFunction {
    _timingFunction = timingFunction;
    float vec[4] = {0.};
    [timingFunction getControlPointAtIndex:1 values:&vec[0]];
    [timingFunction getControlPointAtIndex:2 values:&vec[2]];
    int count = sizeof(vec) / sizeof(vec[0]);
    for (NSUInteger idx = 0; idx < count; idx++) {
        _timingControlPoints[idx] = vec[idx];
    }
}

- (vector_float3)rotateStride:(NSTimeInterval)frameDuration  pipeline:(LyzZMetaxParaboloidPipeline *)pipeline { return 0; }

- (vector_float3)translateStride:(NSTimeInterval)frameDuration  pipeline:(LyzZMetaxParaboloidPipeline *)pipeline { return 0; }

- (vector_float3)rotateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline { return 0; }

- (vector_float3)translateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline { return 0; }

- (BOOL)framesCompleteWith:(LyzZMetaxParaboloidPipeline *)pipeline { return NO; }

- (void)cancel {
    
}

- (simd_float4x4)modelMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    simd::float4x4 mMatrix = lyzzvs::identity();
    mMatrix = lyzzvs::rotationAround_xAxis(pipeline.rotateValue.x) * mMatrix;
    mMatrix = lyzzvs::rotationAround_yAxis(pipeline.rotateValue.y) * mMatrix;
    mMatrix = lyzzvs::rotationAround_zAxis(pipeline.rotateValue.z) * mMatrix;
    mMatrix = lyzzvs::translate(mMatrix, pipeline.translateValue.x, pipeline.translateValue.y, pipeline.translateValue.z);
    if (pipeline.currentIndex < 3) {
        modelMatrix[pipeline.currentIndex] = mMatrix;
    }
    return mMatrix;
}

- (simd_float4x4)viewMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    return viewMatrix;
}

- (float)nearDistance:(float)d target:(float)tdeg {
    /*
     1、当前角度小于目标角度：需要变大当前角度。那么增长为正；
     2、当前角度大于目标角度：需要变小当前角度。那么减小为负；
     */
    int sign = 1;
    if (d > tdeg) {
        sign = -1;
    }
    float result = fmod(fabs(tdeg - d), 360.0f) * sign;
    if (fabs(result) > 180.0f) { /// 寻找较小的旋转角
        result = (360.0f - fabs(result)) * -1 * sign;
    }
    return result;
}

///- pi/4旋转基变换
- (vector_float3)minusPI_1_4_BasisTransform:(vector_float3)point {
    float value = sinf(lyzzvs::deg2rad(45));
    simd::float3 col0 = {
        value,
        value,
        0
    };
    simd::float3 col1 = {
        -1 * value,
        value,
        0
    };
    simd::float3 col2 = {
        0,
        0,
        1
    };
    simd::float3x3 matrix = {
        col0, col1, col2
    };
    return matrix * point;
}

/// - pi * 3/4旋转基变换
- (vector_float3)minusPI_3_4_BasisTransform:(vector_float3)point {
    float value = sinf(lyzzvs::deg2rad(45));
    simd::float3 col0 = {
        -1 * value,
        value,
        0
    };
    simd::float3 col1 = {
        -1 * value,
        -1 * value,
        0
    };
    simd::float3 col2 = {
        0,
        0,
        1
    };
    simd::float3x3 matrix = {
        col0, col1, col2
    };
    return matrix * point;
}
@end

/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidNormalAnimationStrategy ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidNormalAnimationStrategy ()
@end
@implementation LyzZMetaxParaboloidNormalAnimationStrategy {
    /// 面片0位移的4个阶段
    vector_float3 _patch_zero_list[4];
    /// 面片1位移的4个阶段
    vector_float3 _patch_one_list[4];
    /// 每个阶段所需的帧数
    NSUInteger _frameCount[4];
    /// 各个面片当前所处的阶段。比如_stage[0] = 0/1/2/3
    NSUInteger _stage[3];
    /// 各个面片当前阶段帧数计数器。比如_patchFrameIndex[0]=142，即表示面片0在当前阶段的第142帧
    NSUInteger _patchFrameIndex[3];
    /// 需要延迟的帧数，面片1要比面片0慢一半（帧数）
    NSUInteger _delayFrames;
    
    BOOL _initState[3];
}

- (instancetype)initWithFPS:(NSUInteger)fps {
    if (self = [super initWithFPS:fps]) {
        self.type = LyzZVzxParaboloidUniformsNormalType;
        self.timeDuration = 2.0f;
        [self resetToInitial];
        [self initStateModelMatrix];
        simd::float4x4 vMatrix = lyzzvs::identity();
        vMatrix = lyzzvs::matrixSetLookAt(
                                         0.0f, 0.0f, 150.0f, /// eye
                                         0.0f, 0.0f, 0.0f, /// center
                                         0.0f, 1.0f, 0.0f /// up
                                         ) * vMatrix;
        viewMatrix = vMatrix;
    }
    return self;
}

- (void)initStateModelMatrix {
    {  simd::float4x4 mMatrix = lyzzvs::identity();
        vector_float3 rotate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalRotateValueWith:0];
        NSUInteger count = ceil(0.2 * self.fps);
        vector_float3 translate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalTranslateValueWith:0 count:count];
        mMatrix = lyzzvs::rotationAround_xAxis(rotate_val.x) * mMatrix;
        mMatrix = lyzzvs::rotationAround_yAxis(rotate_val.y) * mMatrix;
        mMatrix = lyzzvs::rotationAround_zAxis(rotate_val.z) * mMatrix;
        mMatrix = lyzzvs::translate(mMatrix, translate_val.x, translate_val.y, translate_val.z);
        startMatrix[0] = mMatrix;
    }
    {  simd::float4x4 mMatrix = lyzzvs::identity();
        vector_float3 rotate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalRotateValueWith:1];
        NSUInteger count = ceil(0.2 * self.fps);
        vector_float3 translate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalTranslateValueWith:1 count:count];
        mMatrix = lyzzvs::rotationAround_xAxis(rotate_val.x) * mMatrix;
        mMatrix = lyzzvs::rotationAround_yAxis(rotate_val.y) * mMatrix;
        mMatrix = lyzzvs::rotationAround_zAxis(rotate_val.z) * mMatrix;
        mMatrix = lyzzvs::translate(mMatrix, translate_val.x, translate_val.y, translate_val.z);
        startMatrix[1] = mMatrix;
    }
    {  simd::float4x4 mMatrix = lyzzvs::identity();
        vector_float3 rotate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalRotateValueWith:2];
        NSUInteger count = ceil(0.2 * self.fps);
        vector_float3 translate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalTranslateValueWith:2 count:count];
        mMatrix = lyzzvs::rotationAround_xAxis(rotate_val.x) * mMatrix;
        mMatrix = lyzzvs::rotationAround_yAxis(rotate_val.y) * mMatrix;
        mMatrix = lyzzvs::rotationAround_zAxis(rotate_val.z) * mMatrix;
        mMatrix = lyzzvs::translate(mMatrix, translate_val.x, translate_val.y, translate_val.z);
        startMatrix[2] = mMatrix;
    }
}

- (void)resetToInitial {
    [super resetToInitial];
    bzero(_stage, 3 * sizeof(NSUInteger));
    bzero(_patchFrameIndex, 3 * sizeof(NSUInteger));
    _delayFrames = 0;
    /*
     patch 1: (0,0) -> (-10,2) -> (0,5) -> (10,0) -> (0,0)
     patch 2: (0,0) -> (-10,5) -> (0,10) -> (10,5) -> (0,0)
     */
    float scale = 40.0f;
    _patch_zero_list[0] = [self minusPI_1_4_BasisTransform:(vector_float3){-10.0f/scale, 2.0f/scale, 0.0f}];
    _patch_zero_list[1] = [self minusPI_1_4_BasisTransform:(vector_float3){0.0f, 5.0f/scale, 0.0f}];
    _patch_zero_list[2] = [self minusPI_1_4_BasisTransform:(vector_float3){10.0f/scale, 0.0f, 0.0f}];
    //_patch_zero_list[3] = [self minusPI_1_4_BasisTransform:(vector_float3){0.0f, 0.0f, 0.0f}];

    _patch_one_list[0] = [self minusPI_3_4_BasisTransform:(vector_float3){-10.0f/scale, 5.0f/scale, 0.0f}];
    _patch_one_list[1] = [self minusPI_3_4_BasisTransform:(vector_float3){0.0f, 7.0f/scale, 0.0f}];
    _patch_one_list[2] = [self minusPI_3_4_BasisTransform:(vector_float3){10.0f/scale, 5.0f/scale, 0.0f}];
    //_patch_one_list[3] = [self minusPI_3_4_BasisTransform:(vector_float3){0.0f, 0.0f, 0.0f}];

    NSUInteger frameCounts = ceilf(self.timeDuration * self.fps);
    /// 使用数组是防止后续针对不同阶段有不同的耗时
    _frameCount[0] = frameCounts;
    _frameCount[1] = frameCounts;
    _frameCount[2] = frameCounts;
    _frameCount[3] = frameCounts;
    
    _initState[0] = YES;
    _initState[1] = YES;
    _initState[2] = YES;
}

- (vector_float3)rotateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline {
    return [LyzZMetaxParaboloidNormalAnimationStrategy normalRotateValueWith:pipeline.currentIndex];
}

- (vector_float3)translateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline {
    vector_float3 val = pipeline.translateValue;
    if (0 == pipeline.currentIndex) {
        _patch_zero_list[3] = val;
    }
    if (1 == pipeline.currentIndex) {
        _patch_one_list[3] = val;
    }
    return val;
}

+ (vector_float3)normalRotateValueWith:(NSUInteger)index {
    switch (index) {
        case 0: return (vector_float3){0.0f, 0.0f, -45.0f};
        case 1: return (vector_float3){0.0f, 0.0f, -135.0f};
        case 2: return (vector_float3){0.0f, 0.0f, -135.0f};
    }
    return (vector_float3){0.0f};
}

+ (vector_float3)normalTranslateValueWith:(NSUInteger)index count:(NSUInteger)count {
    vector_float3 result = (vector_float3){0};
    if (0 ==index) {
        float length = 1.0 / count;
        float rad = lyzzvs::deg2rad(45); /// -45
        float y = -1 * length * sin(rad);
        float x = length * cos(rad);
        result = (vector_float3){x, y, 0.0f};
    } else if (1 == index) {
        float length = 0.5 / count;
        float rad = lyzzvs::deg2rad(45); /// -135
        float y = length * sin(rad);
        float x = length * cos(rad);
        result = (vector_float3){x, y, 0.0f};
    }
    return result;
}


- (simd_float4x4)modelMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    NSUInteger index = pipeline.currentIndex;
    vector_float3 rotate_val = [LyzZMetaxParaboloidNormalAnimationStrategy normalRotateValueWith:index];
    simd::float4x4 mMatrix = lyzzvs::identity();
    mMatrix = lyzzvs::rotationAround_xAxis(rotate_val.x) * mMatrix;
    mMatrix = lyzzvs::rotationAround_yAxis(rotate_val.y) * mMatrix;
    mMatrix = lyzzvs::rotationAround_zAxis(rotate_val.z) * mMatrix;
    mMatrix = lyzzvs::translate(mMatrix, pipeline.translateValue.x, pipeline.translateValue.y, pipeline.translateValue.z);
    if (pipeline.currentIndex < 3) {
        modelMatrix[pipeline.currentIndex] = mMatrix;
    }
    return mMatrix;
}

- (simd_float4x4)viewMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    return viewMatrix;
}

- (vector_float3)translateStride:(NSTimeInterval)frameDuration pipeline:(LyzZMetaxParaboloidPipeline *)pipeline {
    NSUInteger index = pipeline.currentIndex;
    if (index >= 2) {
        return {0};
    }
    NSUInteger stage = _stage[index];
    if (stage > 3 || !pipeline || ![pipeline isKindOfClass:[LyzZMetaxParaboloidPipeline class]]) {
        return {0};
    }
    vector_float3 dst_translate;
    NSUInteger totalFrameCount = _frameCount[index];
    if (0 == index) {
        dst_translate = _patch_zero_list[stage];
        _delayFrames = MIN(++_delayFrames, totalFrameCount / 2);
    } else {
        dst_translate = _patch_one_list[stage];
    }
    NSUInteger fIdx = _patchFrameIndex[index];
    if (0 == fIdx) {
        _translates[index] = pipeline.translateValue;
    }
    vector_float3 src_translate = _translates[index];
    float x = (dst_translate.x - src_translate.x) / totalFrameCount;
    float y = (dst_translate.y - src_translate.y) / totalFrameCount;
    vector_float3 dst_ptr = vector_float3{x, y, 0.0f};
    if (fIdx == totalFrameCount - 1) {
        /// 进入下一阶段，并且将当前面片的帧数重置
        _stage[index] = (stage+1)%4;
        _patchFrameIndex[index] = 0;
    } else {
        _patchFrameIndex[index] = fIdx + 1;
    }
    return dst_ptr;
}

- (BOOL)framesCompleteWith:(LyzZMetaxParaboloidPipeline *)pipeline {
    if (pipeline.currentIndex != 1) {
        return [super framesCompleteWith:pipeline];
    }
    NSUInteger totalFrameCount = _frameCount[0];
    if (_delayFrames < totalFrameCount / 2) {
        return YES;
    }
    return NO;
}
@end
/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidListenningAnimationStrategy ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidListenningAnimationStrategy ()
@end
@implementation LyzZMetaxParaboloidListenningAnimationStrategy {
    BOOL _initState[3];
    NSUInteger _maxCount;
}
- (instancetype)initWithFPS:(NSUInteger)fps {
    if (self = [super initWithFPS:fps]) {
        self.type = LyzZVzxParaboloidUniformsListenningType;
        self.timeDuration = 6; /// 6s旋转360
        _maxCount = self.timeDuration * fps;
        [self initStateModelMatrix];
    }
    return self;
}

- (void)resetToInitial {
    [super resetToInitial];
    _initState[0] = YES;
    _initState[1] = YES;
    _initState[2] = YES;
}

- (vector_float3)rotateStride:(NSTimeInterval)frameDuration  pipeline:(LyzZMetaxParaboloidPipeline *)pipeline {
    return {0};
}

- (vector_float3)rotateStrideWithPipeline:(LyzZMetaxParaboloidPipeline *)pipeline {
    vector_float3 result = (vector_float3){0};
    NSUInteger index = pipeline.currentIndex;
    if (index >= 3) {
        return result;
    }
    float angular = 360.0f / _maxCount;
    return (vector_float3){angular, angular, angular};
}

- (vector_float3)rotateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline {
    return [LyzZMetaxParaboloidListenningAnimationStrategy listeningRotateValue:pipeline.currentIndex];
}

//- (simd_float4x4)viewMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
//    simd::float4x4 vMatrix = lyzzvs::identity();
//    vMatrix = lyzzvs::matrixSetLookAt(
//                                     0.3f, 3.0f, 100.0f, /// eye
//                                     0.0f, 0.0f, 0.0f, /// center
//                                     0.0f, 1.0f, 0.0f /// up
//                                     ) * vMatrix;
//    return vMatrix;
//}

+ (vector_float3)listeningRotateValue:(NSUInteger)patchIndex {
    vector_float3 result = (vector_float3){0};
    switch (patchIndex) {
        case 0: result = (vector_float3){30.0f, 0.0f, -60.0f}; break;
        case 1: result = (vector_float3){125.0f, 0.0f, 100.0f}; break;
        case 2: result = (vector_float3){0.0f, 0.0f, 210.0f}; break;
        default: break;
    }
    return result;
}

- (void)initStateModelMatrix {
    { simd::float4x4 mMatrix = lyzzvs::identity();
        vector_float3 val_vec = [LyzZMetaxParaboloidListenningAnimationStrategy listeningRotateValue:0];
        mMatrix = lyzzvs::rotationAround_zAxis(val_vec.z) * mMatrix;
        mMatrix = lyzzvs::rotationAround_xAxis(val_vec.x) * mMatrix;
        mMatrix = lyzzvs::rotationAround_yAxis(val_vec.y) * mMatrix;
        startMatrix[0] = mMatrix;
    }
    { simd::float4x4 mMatrix = lyzzvs::identity();
        vector_float3 val_vec = [LyzZMetaxParaboloidListenningAnimationStrategy listeningRotateValue:1];
        mMatrix = lyzzvs::rotationAround_zAxis(val_vec.z) * mMatrix;
        mMatrix = lyzzvs::rotationAround_xAxis(val_vec.x) * mMatrix;
        mMatrix = lyzzvs::rotationAround_yAxis(val_vec.y) * mMatrix;
        startMatrix[1] = mMatrix;
    }
    {  simd::float4x4 mMatrix = lyzzvs::identity();
        vector_float3 val_vec = [LyzZMetaxParaboloidListenningAnimationStrategy listeningRotateValue:2];
        mMatrix = lyzzvs::rotationAround_zAxis(val_vec.z) * mMatrix;
        mMatrix = lyzzvs::rotationAround_xAxis(val_vec.x) * mMatrix;
        mMatrix = lyzzvs::rotationAround_yAxis(val_vec.y) * mMatrix;
        startMatrix[2] = mMatrix;
    }
}

- (simd_float4x4)modelMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    simd::float4x4 mMatrix = lyzzvs::identity();
    NSUInteger index = pipeline.currentIndex;
    if (index > 2) {
        return mMatrix;
    }
    if (_initState[index]) {
        _initState[index] = NO;
        mMatrix = mMatrix * startMatrix[index];
        modelMatrix[index] = mMatrix;
        return mMatrix;
    }
    mMatrix = modelMatrix[index];
    vector_float3 rotateStride = [self rotateStrideWithPipeline:pipeline];
    switch (index) {
        case 0: {
            mMatrix = lyzzvs::rotationAround_yAxis(rotateStride.y) * mMatrix;
            mMatrix = lyzzvs::rotationAround_xAxis(rotateStride.x) * mMatrix;
        }
            break;
        case 1: {
            mMatrix = lyzzvs::rotationAround_xAxis(rotateStride.x) * mMatrix;
            mMatrix = lyzzvs::rotationAround_zAxis(rotateStride.z) * mMatrix;
        }
            break;
        case 2: {
            mMatrix = lyzzvs::rotationAround_zAxis(rotateStride.z) * mMatrix;
            mMatrix = lyzzvs::rotationAround_yAxis(rotateStride.y) * mMatrix;
        }
            break;
        default:
            break;
    }
    modelMatrix[index] = mMatrix;
    return mMatrix;
}
@end

/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidLoadingAnimationStrategy ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidLoadingAnimationStrategy ()
@end
@implementation LyzZMetaxParaboloidLoadingAnimationStrategy {
    float _eps;
    NSUInteger _patchFrameIndex[3];
    NSUInteger _maxFrames;
    float _lastProgress[3];
    float _currentProgress;
    int _sign;
    BOOL _cancelAnimation;
}

- (instancetype)initWithFPS:(NSUInteger)fps {
    if (self = [super initWithFPS:fps]) {
        [self resetToInitial];
        self.timeDuration = 2.0f;
        _maxFrames = self.timeDuration * fps;
        self.type = LyzZVzxParaboloidUniformsLoadingType;
        _eps = 1.0f / (1000.0f * _maxFrames);
        self.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.36f :0.05f :0.49f :1.0f];
        [self initStateModelMatrix];
    }
    return self;
}

- (void)resetToInitial {
    [super resetToInitial];
    self.zProgress = 0.0;
    self.lhs = 1;
    self.rhs = 0;
    _sign = 1;
    _cancelAnimation = NO;
    bzero(_patchFrameIndex, sizeof(_patchFrameIndex));
    bzero(_lastProgress, sizeof(_lastProgress));
    _currentProgress = 0.0f;
}

- (vector_float3)rotateStartValueFor:(LyzZMetaxParaboloidPipeline *)pipeline {
    return [LyzZMetaxParaboloidLoadingAnimationStrategy loadingRotateValue:pipeline.currentIndex];
}

+ (vector_float3)loadingRotateValue:(NSUInteger)pipeIndex {
    return (vector_float3){0.0f, 0.0f, 180.0f};
}

- (void)initStateModelMatrix {
    simd::float4x4 mMatrix = lyzzvs::identity();
    vector_float3 val_vec = [LyzZMetaxParaboloidLoadingAnimationStrategy loadingRotateValue:0];
    mMatrix = lyzzvs::rotationAround_xAxis(val_vec.x) * mMatrix;
    mMatrix = lyzzvs::rotationAround_yAxis(val_vec.y) * mMatrix;
    mMatrix = lyzzvs::rotationAround_zAxis(val_vec.z) * mMatrix;
    mMatrix = lyzzvs::translate(mMatrix, 0.0f, 0.0f, 0.0f);
    startMatrix[0] = mMatrix;
    startMatrix[1] = mMatrix;
    startMatrix[2] = mMatrix;
}

- (vector_float3)rotateStride:(NSTimeInterval)frameDuration pipeline:(LyzZMetaxParaboloidPipeline *)pipeline {
    NSUInteger index = pipeline.currentIndex;
    if (index > 2) {
        return {0};
    }
    float progress = 0.0f;
    NSUInteger currentFrame = _patchFrameIndex[index];
    if (currentFrame == _maxFrames) {
        currentFrame = 0;
        _lastProgress[index] = 0.0f;
    }
    static lyzzvs::CurveBezier bezier(
                              _timingControlPoints[0],
                              _timingControlPoints[1],
                              _timingControlPoints[2],
                              _timingControlPoints[3]);
    
    if (index == 0) {
        if (currentFrame == _maxFrames - 1) {
            self.rhs = !self.rhs;
            self.lhs = !self.lhs;
        }
        float t = (currentFrame * 1.0f) / _maxFrames;
        progress = bezier.solve(t, _eps);
        self.zProgress = progress;
        _currentProgress = progress;
    }
    float ang = (_currentProgress - _lastProgress[index]) * 360.0f;
    vector_float3 rotateValue = {ang, ang, 0.0f};
    _lastProgress[index] = _currentProgress;
    currentFrame++;
    _patchFrameIndex[index] = currentFrame%_maxFrames;
    return rotateValue;
}

- (simd_float4x4)modelMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    if (pipeline.currentIndex > 2) {
        return lyzzvs::identity();
    }
    simd::float4x4 mMatrix = startMatrix[pipeline.currentIndex];
    vector_float3 axix = (vector_float3){1.0f, 1.0f, 0.0f};
    mMatrix = lyzzvs::rotation(pipeline.rotateValue.x, axix) * mMatrix;
    mMatrix = lyzzvs::rotationAround_zAxis(45.0f) * mMatrix;
    if (pipeline.currentIndex < 3) {
        modelMatrix[pipeline.currentIndex] = mMatrix;
    }
    return mMatrix;
}

- (void)cancel {
    _cancelAnimation = YES;
}

- (BOOL)framesCompleteWith:(LyzZMetaxParaboloidPipeline *)pipeline {
    if (_cancelAnimation) {
        return YES;
    }
    NSUInteger index = pipeline.currentIndex;
    if (index > 2) {
        return YES;
    }
    NSUInteger currentFrame = _patchFrameIndex[index];
    return (currentFrame >= _maxFrames - 1 && _cancelAnimation);
}
@end

/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidTransitionAnimationStrategy ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidTransitionAnimationStrategy () {
    NSUInteger _counts[3];
    NSUInteger _maxCount;
    simd_float4x4 strideMatrix[3];
    BOOL _isComplete;
}
@end

@implementation LyzZMetaxParaboloidTransitionAnimationStrategy
- (instancetype)initWithFPS:(NSUInteger)fps {
    if (self = [super initWithFPS:fps]) {
        self.type = LyzZVzxParaboloidUniformsTransitionType;
        self.timeDuration = 0.2;
        _maxCount = ceil(self.timeDuration * self.fps);
        [self resetToInitial];
    }
    return self;
}

- (void)resetToInitial {
    [super resetToInitial];
    _isComplete = NO;
    bzero(_counts, 3 * sizeof(NSUInteger));
    bzero(strideMatrix, 3 * sizeof(simd_float4x4));
}

- (simd_float4x4)modelMatrixWithPatch:(LyzZMetaxParaboloidPipeline *)pipeline {
    NSUInteger index = pipeline.currentIndex;
    if (index > 3 || _isComplete) {
        return modelMatrix[index];
    }
    simd_float4x4 nsm = prevmMatrix[index];
    float step = _counts[index] + 1.0f;
    simd::float4 col0 = {
        nsm.columns[0].x + strideMatrix[index].columns[0].x * step,
        nsm.columns[0].y + strideMatrix[index].columns[0].y * step,
        nsm.columns[0].z + strideMatrix[index].columns[0].z * step,
        nsm.columns[0].w + strideMatrix[index].columns[0].w * step
    };
    simd::float4 col1 = {
        nsm.columns[1].x + strideMatrix[index].columns[1].x * step,
        nsm.columns[1].y + strideMatrix[index].columns[1].y * step,
        nsm.columns[1].z + strideMatrix[index].columns[1].z * step,
        nsm.columns[1].w + strideMatrix[index].columns[1].w * step
    };
    simd::float4 col2 = {
        nsm.columns[2].x + strideMatrix[index].columns[2].x * step,
        nsm.columns[2].y + strideMatrix[index].columns[2].y * step,
        nsm.columns[2].z + strideMatrix[index].columns[2].z * step,
        nsm.columns[2].w + strideMatrix[index].columns[2].w * step
    };
    simd::float4 col3 = {
        nsm.columns[3].x + strideMatrix[index].columns[3].x * step,
        nsm.columns[3].y + strideMatrix[index].columns[3].y * step,
        nsm.columns[3].z + strideMatrix[index].columns[3].z * step,
        nsm.columns[3].w + strideMatrix[index].columns[3].w * step
    };
    simd::float4x4 matrix = {col0, col1, col2, col3};
    modelMatrix[index] = matrix;
    return matrix;
}

- (void)setPipelinesAngular:(vector_float3 *)angular
                  translate:(vector_float3 *)translates
                     length:(NSUInteger)length {
    for (int i = 0; i < 3; i++) {
        simd_float4x4 lsm = nextmMatrix[i];
        simd_float4x4 nsm = prevmMatrix[i];
        float div = (_maxCount * 1.0f);
        simd::float4 col0 = {
            (lsm.columns[0].x - nsm.columns[0].x)/div,
            (lsm.columns[0].y - nsm.columns[0].y)/div,
            (lsm.columns[0].z - nsm.columns[0].z)/div,
            (lsm.columns[0].w - nsm.columns[0].w)/div
        };
        simd::float4 col1 = {
            (lsm.columns[1].x - nsm.columns[1].x)/div,
            (lsm.columns[1].y - nsm.columns[1].y)/div,
            (lsm.columns[1].z - nsm.columns[1].z)/div,
            (lsm.columns[1].w - nsm.columns[1].w)/div
        };
        simd::float4 col2 = {
            (lsm.columns[2].x - nsm.columns[2].x)/div,
            (lsm.columns[2].y - nsm.columns[2].y)/div,
            (lsm.columns[2].z - nsm.columns[2].z)/div,
            (lsm.columns[2].w - nsm.columns[2].w)/div
        };
        simd::float4 col3 = {
            (lsm.columns[3].x - nsm.columns[3].x)/div,
            (lsm.columns[3].y - nsm.columns[3].y)/div,
            (lsm.columns[3].z - nsm.columns[3].z)/div,
            (lsm.columns[3].w - nsm.columns[3].w)/div
        };
        simd::float4x4 result = {col0, col1, col2, col3};
        strideMatrix[i] = result;
    }
}

- (BOOL)framesCompleteWith:(LyzZMetaxParaboloidPipeline *)pipeline {
    NSUInteger index = pipeline.currentIndex;
    BOOL result = NO;
    NSInteger count = _counts[index];
    if (count >= _maxCount - 1) {
        result = YES;
        _isComplete = result;
        NSUInteger count = ceil(0.2 * self.fps);
        pipeline.translateValue = [LyzZMetaxParaboloidNormalAnimationStrategy normalTranslateValueWith:index count:count];
        return result;
    }
    _counts[index] = count+1;
    return result;
}
@end

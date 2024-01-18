//
//  LyzZMetaxParaboloidPipeline.m
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/6/9.
//
// https://www.raywenderlich.com/728-metal-tutorial-with-swift-3-part-2-moving-to-3d
/*
 
      局部空间：可以理解为：模型局部本身，无参照物
            |
            |
 模型变换矩阵(Model Matrix)
            |
            |
       世界空间：多个模型揉在一起，有相对位置（揉的方式有平移、旋转、缩放）
            |
            |
 视图变换矩阵(View Matrix)
            |
            |
       观察空间：定义了camera，包含了up、look-at等向量
            |
            |
 投影变换矩阵（Projection Matrix）
            |
            |
      裁剪空间：近平面视角外的都被裁剪
            |
            |
  视口变换(Viewport)
            |
            |
  屏幕归一化坐标
 */
#import "LyzZMetaxParaboloidPipeline.h"
#import "LyzZMetaxParaboloidMath.h"

float kLyzZMetaxParaboloidPipelineNearValue = 0.1f;
float kLyzZMetaxParaboloidPipelineFarValue = 20.0f;

@interface LyzZMetaxParaboloidPipeline ()
@end

@implementation LyzZMetaxParaboloidPipeline {
    simd::float4x4 _mMatrix;
    simd::float4x4 _pMatrix;
    
    struct {
        unsigned int resize:1;
        unsigned int render:1;
    } _delegateFlag;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _mMatrix = {0, 0, 0, 0};
    _pMatrix = {0, 0, 0, 0};
}

#pragma mark - setter and getter

- (void)setFramesPerSecond:(NSInteger)framesPerSecond {
    _framesPerSecond = framesPerSecond;
}

#pragma mark - matirx
/// 模型矩阵
- (simd_float4x4)modelMatrix {
    return [[self.delegate currentAnimationStrategy] modelMatrixWithPatch:self];
}

- (simd_float4x4)viewMatrix {
    return [[self.delegate currentAnimationStrategy] viewMatrixWithPatch:self];
}

- (simd_float4x4)projectionMatrix:(CGSize)drawSize {
    if (_pMatrix.columns[0].x > 0.001) {
        return _pMatrix;
    }
    const float near = kLyzZMetaxParaboloidPipelineNearValue;
    const float far = kLyzZMetaxParaboloidPipelineFarValue;
    /// left, right, bottom, top, near, far
    float value = 0.3;
    simd::float4x4 pMatrix = lyzzvs::orthographicProjection(-value, value, -value, value, near, far);
    _pMatrix = pMatrix;
    return pMatrix;
}

#pragma mark - uniforms
- (BOOL)buildUniformsBuffer:(LyzZVzxParaboloidUniforms *)bufferPtr drawableSize:(CGSize)drawSize {
    LyzZVzxParaboloidUniforms uniforms;
    uniforms.mMatrix = [self modelMatrix];
    uniforms.vMatrix = [self viewMatrix];
    uniforms.pMatrix = [self projectionMatrix:drawSize];
    uint16_t flag = 0;
    NSUInteger index = [self currentIndex];
    flag |= (index & 0x3);
    uniforms.flag = flag;
    /// 全局常量需要在cpu和gpu中同时访问
    if (bufferPtr) {
        *bufferPtr = uniforms;
    }
    return YES;
}

#pragma mark - render
- (void)pipelineModelMatrix:(NSTimeInterval)duration {
    LyzZMetaxParaboloidAnimationStrategy *strategy = [self.delegate currentAnimationStrategy];
    if ([strategy framesCompleteWith:self]) {
        [self.delegate pipelineStageDidCompleteShouldChangeStrategy:self];
        self.rotateValue = [strategy.next rotateStartValueFor:self];
        self.translateValue = [strategy.next translateStartValueFor:self];
        return;
    }
    vector_float3 rotate = [strategy rotateStride:duration pipeline:self];
    vector_float3 translate = [strategy translateStride:duration pipeline:self];
    float deg_2pi = 360.0f;
    self.rotateValue = (vector_float3) {
        fmod(self.rotateValue.x + rotate.x, deg_2pi),
        fmod(self.rotateValue.y + rotate.y, deg_2pi),
        fmod(self.rotateValue.z + rotate.z, deg_2pi)
    };
    self.translateValue = (vector_float3) {
        self.translateValue.x + translate.x,
        self.translateValue.y + translate.y,
        self.translateValue.z + translate.z
    };
}

@end


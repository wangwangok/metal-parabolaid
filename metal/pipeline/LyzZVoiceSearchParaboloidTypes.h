//
//  LyzZMetaxParaboloidTypes.h
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/5/31.
//

#ifndef LyzZMetaxParaboloidTypes_h
#define LyzZMetaxParaboloidTypes_h

#include <simd/simd.h>

typedef enum LyzZVzxParaboloidVertextInputIndex {
    LyzZVzxParaboloidVertextInputVerticesIndex = 0,
    LyzZVzxParaboloidVertextInputUniformsIndex = 1
} LyzZVzxParaboloidVertextInputIndex;


typedef enum : uint8_t {
    LyzZVzxParaboloidUniformsNormalType              = 0,
    LyzZVzxParaboloidUniformsListenningType       = 1,
    LyzZVzxParaboloidUniformsLoadingType            = 2,
    LyzZVzxParaboloidUniformsTransitionType       = 3
} LyzZVzxParaboloidUniformsType;

typedef struct  {
    vector_float4 position;
    vector_float4 ucolor;
    vector_float4 vcolor;
    vector_float4 wcolor;
} LyzZVzxParaboloidVertex;

typedef struct{
    /// 模型矩阵 model
    simd::float4x4 mMatrix;
    /// 视图矩阵
    simd::float4x4 vMatrix;
    /// 透视投影矩阵
    simd::float4x4 pMatrix;
    /// 视口大小
    vector_uint2 viewportSize;
    /// 面板索引
    /// 低2位放置当前面片索引
    /// 中间4位放置当前面片所处的阶段
    /// 其余位待定
    /// 0000000000 0000            00
    ///                    stage type  patch index
    uint16_t flag;
    /// z轴形变系数，用于识别态形变动画
    float zProgress;
    uint lhs;
    uint rhs;
} LyzZVzxParaboloidUniforms;

/// 包含3个面片统一数据
typedef struct{
    LyzZVzxParaboloidUniforms items[3];
} LyzZVzxParaboloidLayerUniforms;


#endif /* LyzZMetaxParaboloidTypes_h */

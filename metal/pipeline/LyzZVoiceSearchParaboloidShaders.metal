//
//  LyzZMetaxParaboloidShaders.metal
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/5/31.
//

#include <metal_stdlib>
#include "LyzZMetaxParaboloidTypes.h"
using namespace metal;

struct LyzZVzxParaboloidProjectedVertex {
    float4 posistion [[position]];
    float4 color;
    /// 相机位置
    float4 camera;
    uint16_t flag;
};

LyzZVzxParaboloidUniformsType uniformType(uint16_t flag) {
    LyzZVzxParaboloidUniformsType type = (LyzZVzxParaboloidUniformsType)((flag >> 2) & 0xf);
    return type;
}

int uniformIndex(uint16_t flag) {
    int index = (flag & 0x3);
    return index;
}

vertex LyzZVzxParaboloidProjectedVertex paraboloidVertexShader(
                                                              uint vertexID [[ vertex_id ]],
                                                              uint instanceID [[instance_id]], /// https://metalbyexample.com/instanced-rendering/ Accessing Per-Instance Data in Shaders
                                                              constant LyzZVzxParaboloidVertex *vertexArray [[ buffer(0) ]],
                                                              constant LyzZVzxParaboloidLayerUniforms &uniforms [[ buffer(1) ]]
                                                  ) {
    
    LyzZVzxParaboloidProjectedVertex out;
    LyzZVzxParaboloidUniforms instanceUniform = uniforms.items[instanceID];
    LyzZVzxParaboloidVertex vertx = vertexArray[vertexID];
    float4 pos = vertx.position;
    float progress = instanceUniform.zProgress;
    uint lhs = instanceUniform.lhs + 2;
    uint rhs = instanceUniform.rhs + 2;
    float z = pos[rhs] + (pos[lhs] - pos[rhs]) * progress;
    //float z = pos.z + (pos.w - pos.z) * progress;
    float4 pos4 = { 0, 0, z, 1 };
    pos4.xy = pos.xy ;
    /// 三维坐标透视投影变换
    simd::float4x4 mMatrix = instanceUniform.mMatrix;
    simd::float4x4 vMatrix = instanceUniform.vMatrix;
    simd::float4x4 pMatrix = instanceUniform.pMatrix;
    uint16_t flag = instanceUniform.flag;
    int index = uniformIndex(flag);
    out.flag = flag;
    /// 本地空间 -> 世界空间 -> 观察空间 -> 裁剪空间
    out.posistion = pMatrix * vMatrix * mMatrix * pos4;
    float4 col;
    switch (index) {
        case 0:col = vertexArray[vertexID].ucolor; break;
        case 1:col = vertexArray[vertexID].vcolor; break;
        case 2:col = vertexArray[vertexID].wcolor; break;
    }
    out.color =  col;
    return out;
}

fragment half4 paraboloidFragmentShader(
                                         LyzZVzxParaboloidProjectedVertex in [[stage_in]]) {
    return half4(in.color.r, in.color.g, in.color.b, in.color.a);
}

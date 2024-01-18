//
//  LyzZMetaxParaboloidMath.h
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/6/3.
//

#ifndef LyzZMetaxParaboloidMath_h
#define LyzZMetaxParaboloidMath_h

#include <simd/simd.h>

namespace lyzzvs {
struct CurveBezier {
    /// 一共四个顶点：(0,0), (p1x,p1y), (p2x,p2y) (1,1)
    CurveBezier(double p1x, double p1y, double p2x, double p2y) {
        /// 三阶贝塞尔曲线通用公式
        /// B(t) = (1-t)^3*p0 + 3t(1-t)^2*p1 + 3t^2(1-t)*p2 + t^3*p3
        cx = 3.0 * p1x;
        bx = 3.0 * (p2x - p1x) - cx;
        ax = 1.0 - cx -bx;

        cy = 3.0 * p1y;
        by = 3.0 * (p2y - p1y) - cy;
        ay = 1.0 - cy - by;
    }
    
    double solve(double x, double epsilon);
    
private:
    /// 曲线x轴采样
    double sampleCurveX(double t) {
        return ax * t * t * t + bx * t * t + cx * t;
    }
    
    /// 曲线y轴采样
    double sampleCurveY(double t) {
        return ay * t * t * t + by * t * t + cy * t;
    }

    /// 迭代采样x
    double sampleCurveDerivativeX(double t) {
        return 3.0f * ax * t * t + 2.0f * bx * t + 1.0f * cx;
    }

    double solveCurveX(double x, double epsilon) ;
    
private:
    double ax;
    double bx;
    double cx;

    double ay;
    double by;
    double cy;
};

void matrixCopy(simd_float4x4 * const srcMatrix, simd_float4x4 *dstMatrix, size_t len);

/// 角度转弧度
float deg2rad(float deg);

/// 单位矩阵
simd::float4x4 identity();

/// 透视变换
/// fov: 👀的在纵轴的视野大小
/// aspect: 近平面和远平面（相似的）width和height的比例
/// near: 近屏幕到相机的位置
/// far: 远屏幕到相机的位置
simd::float4x4 perspectiveProjection(float fov, float aspect, float near, float far);

/// 指定裁剪的体积
/// left和right：指定近平面的宽度
/// bottom和top：指定近平面的高度
/// nearZ和farZ：指定远近平面
simd::float4x4 frustum(float left, float right, float bottom, float top, float nearZ, float farZ);

/// 正射投影
/// left和right：指定近平面的宽度
/// bottom和top：指定近平面的高度
/// nearZ和farZ：指定远近平面
simd::float4x4 orthographicProjection(float left, float right, float bottom, float top, float nearZ, float farZ);

/// 旋转
simd::float4x4 rotation(float angle, simd::float3 vec);

/// 绕x轴旋转
simd::float4x4 rotationAround_xAxis(float angle);

/// 绕y轴旋转
simd::float4x4 rotationAround_yAxis(float angle);

/// 绕z轴旋转
simd::float4x4 rotationAround_zAxis(float angle);

/// 平移
simd::float4x4 translate(simd::float4x4 matrix, float tx, float ty, float tz);

simd::float4x4 matrixSetLookAt(float eyeX, float eyeY, float eyeZ,
                               float centerX, float centerY, float centerZ,
                               float upX, float upY, float upZ);
}

#endif /* LyzZMetaxParaboloidMath_h */

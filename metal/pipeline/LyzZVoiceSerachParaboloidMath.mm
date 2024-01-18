//
//  LyzZMetaxParaboloidMath.m
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/6/3.
//

#import <Foundation/Foundation.h>
#import "LyzZMetaxParaboloidMath.h"

/// 采样
double lyzzvs::CurveBezier::solve(double x, double epsilon) {
    return sampleCurveY(solveCurveX(x, epsilon));
}

double lyzzvs::CurveBezier::solveCurveX(double x, double epsilon) {
    double t0;
    double t1;
    double t2 = x;
    double x2;
    double derivative;
    /// https://zh.wikipedia.org/zh-hans/%E7%89%9B%E9%A1%BF%E6%B3%95
    /// 牛顿迭代求解
    for (int i = 0; i < 8; i++) {
        x2 = sampleCurveX(t2) - x;
        if (fabs (x2) < epsilon) return t2;
        derivative = sampleCurveDerivativeX(t2);
        if (fabs(derivative) < 1e-6) break;
        t2 = t2 - x2 / derivative;
    }

    t0 = 0.0;
    t1 = 1.0;
    t2 = x;

    if (t2 < t0) return t0;
    if (t2 > t1) return t1;

    while (t0 < t1) {
        x2 = sampleCurveX(t2);
        if (fabs(x2 - x) < epsilon) return t2;
        if (x > x2) {
            t0 = t2;
        } else {
            t1 = t2;
        }
        t2 = (t1 - t0) * 0.5 + t0;
    }
    return t2;
}

void lyzzvs::matrixCopy(simd_float4x4 * const srcMatrix, simd_float4x4 *dstMatrix, size_t len) {
    if (srcMatrix == nullptr || dstMatrix == nullptr) {
        return;
    }
    for (size_t i = 0; i < len; i++) {
        dstMatrix[i].columns[0].x = srcMatrix[i].columns[0].x;
        dstMatrix[i].columns[0].y = srcMatrix[i].columns[0].y;
        dstMatrix[i].columns[0].z = srcMatrix[i].columns[0].z;
        dstMatrix[i].columns[0].w = srcMatrix[i].columns[0].w;
        
        dstMatrix[i].columns[1].x = srcMatrix[i].columns[1].x;
        dstMatrix[i].columns[1].y = srcMatrix[i].columns[1].y;
        dstMatrix[i].columns[1].z = srcMatrix[i].columns[1].z;
        dstMatrix[i].columns[1].w = srcMatrix[i].columns[1].w;
        
        dstMatrix[i].columns[2].x = srcMatrix[i].columns[2].x;
        dstMatrix[i].columns[2].y = srcMatrix[i].columns[2].y;
        dstMatrix[i].columns[2].z = srcMatrix[i].columns[2].z;
        dstMatrix[i].columns[2].w = srcMatrix[i].columns[2].w;
        
        dstMatrix[i].columns[3].x = srcMatrix[i].columns[3].x;
        dstMatrix[i].columns[3].y = srcMatrix[i].columns[3].y;
        dstMatrix[i].columns[3].z = srcMatrix[i].columns[3].z;
        dstMatrix[i].columns[3].w = srcMatrix[i].columns[3].w;
    }
}

float lyzzvs::deg2rad(float deg) {
    return deg * (M_PI / 180);
}

/// 获取向量长度
static float vector3Length(simd::float3 vector) {
    return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z);
}

/// 向量取反
static __inline__ simd::float3 vector3Negate(simd::float3 vector) {
    simd::float3 v = { -vector.x, -vector.y, -vector.z };
    return v;
}

/// 向量加法
static __inline__ simd::float3 vector3Add(simd::float3 lhs, simd::float3 rhs) {
    simd::float3 result = {
        lhs.x + rhs.x,
        lhs.y + rhs.y,
        lhs.z + rhs.z
    };
    return result;
}

/// 向量叉乘
static __inline__ simd::float3 vector3CrossProduct(simd::float3 lhs, simd::float3 rhs) {
    /*
     https://www.shuxuele.com/algebra/vectors-cross-product.html
     cx = AyBz − AzBy
     cy = AzBx − AxBz
     cz = AxBy − AyBx
     */
    simd::float3 v = {
        lhs.y * rhs.z - rhs.y * lhs.z,
        lhs.z * rhs.x - lhs.x * rhs.z,
        lhs.x * rhs.y - lhs.y * rhs.x
    };
    return v;
}

/// 向量点乘
static __inline__ float vector3DotProduct(simd::float3 lhs, simd::float3 rhs) {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
}

/// 归一化
static __inline__ simd::float3 vector3Normalize(simd::float3 vector) {
    float scale = 1.0f / vector3Length(vector);
    simd::float3 v = { vector.x * scale, vector.y * scale, vector.z * scale };
    return v;
}

/// 单位矩阵
simd::float4x4 lyzzvs::identity() {
    /// 列优先
    simd::float4 col1 = { 1, 0, 0, 0 };
    simd::float4 col2 = { 0, 1, 0, 0 };
    simd::float4 col3 = { 0, 0, 1, 0 };
    simd::float4 col4 = { 0, 0, 0, 1 };
    simd::float4x4 matrix = {col1, col2, col3, col4};
    return matrix;
}

/// https://learnopengl-cn.github.io/01%20Getting%20started/08%20Coordinate%20Systems/#_6
/// glm::perspective
/// https://github.com/g-truc/glm/blob/0.9.5/glm/gtc/matrix_transform.inl#L207-L229
simd::float4x4 lyzzvs::perspectiveProjection(float fov, float aspect, float near, float far) {
    /// 透视矩阵
    /*
     http://www.songho.ca/opengl/gl_projectionmatrix.html
     左乘
     _                                                                      -
     | n/r,    0,      0,                        0                    |        x
     | 0,        n/t,  0,                        0                    |    *  y
     | 0,        0,      -(f+n)/(f-n),    -2*f*n/(f-n) |        z
     | 0,        0,      -1,                      0                    |        w
     -                                                                      -
     
     右乘
                      _                                                    _
                      | n/r,    0,      0,                        0  |
                      | 0,        n/t,  0,                        0  |
    x,y,z,w  *  | 0,        0,      -(f+n)/(f-n),    -1 |
                      | 0,        0,      -2*f*n/(f-n),    0  |
                      -                                                    -
     */
    /// simd::float4x4 列优先
    float tanHalfFovy = tan(fov * 0.5);
    /// r = aspect * tanHalfFovy * near;
    /// l1_x = near / r => 1 / aspect * tanHalfFovy
    simd::float4 col0 = {1/(tanHalfFovy * aspect), 0, 0, 0 };
    /// n/t 刚好是正切的倒数
    simd::float4 col1 = { 0, 1/tanHalfFovy, 0, 0 };
    simd::float4 col2 = { 0, 0, -(far + near) / (far - near), -1};
    simd::float4 col3 = { 0, 0, (-2.0f * far * near) / (far - near), 0};
    simd::float4x4 mat = {col0, col1, col2, col3};
    return mat;
}

simd::float4x4 lyzzvs::frustum(float left, float right, float bottom, float top, float nearZ, float farZ) {
    float ral = right + left;
    float rsl = right - left;
    float tsb = top - bottom;
    float tab = top + bottom;
    float fan = farZ + nearZ;
    float fsn = farZ - nearZ;
    
    simd::float4 col0 = {2.0f * nearZ / rsl, 0.0f, 0.0f, 0.0f};
    simd::float4 col1 = {0.0f, 2.0f * nearZ / tsb, 0.0f, 0.0f};
    simd::float4 col2 = {ral / rsl, tab / tsb, -fan / fsn, -1.0f};
    simd::float4 col3 = {0.0f, 0.0f, (-2.0f * farZ * nearZ) / fsn, 0.0f};
    simd::float4x4 mat = {col0, col1, col2, col3};

    return mat;
}

simd::float4x4 lyzzvs::orthographicProjection(float left, float right, float bottom, float top, float nearZ, float farZ) {
    float ral = right + left;
    float rsl = right - left;
    float tab = top + bottom;
    float tsb = top - bottom;
    float fan = farZ + nearZ;
    float fsn = farZ - nearZ;

    simd::float4 col0 = {2.0f / rsl, 0.0f, 0.0f, -ral / rsl};
    simd::float4 col1 = {0.0f, 2.0f / tsb, 0.0f, -tab / tsb};
    simd::float4 col2 = {0.0f, 0.0f, -2.0f / fsn, -fan / fsn};
    simd::float4 col3 = {0.0f, 0.0f, 0.0f, 1.0f};
    simd::float4x4 mat = {col0, col1, col2, col3};
    
    return mat;
}

/// https://github.com/g-truc/glm/blob/0.9.5/glm/gtc/matrix_transform.inl#L48-L80
simd::float4x4 lyzzvs::rotation(float angle, simd::float3 vec) {
    angle = deg2rad(angle);
    
    simd::float3 v = simd_normalize(vec);
    float cos = cosf(angle);
    float cosp = 1.0f - cos;
    float sin = sinf(angle);
    simd::float4 col0 = {
        cos + cosp * v.x * v.x,
        cosp * v.x * v.y - v.z * sin,
        cosp * v.x * v.z + v.y * sin,
        0.0f
    };
    simd::float4 col1 = {
        cosp * v.x * v.y + v.z * sin,
        cos + cosp * v.y * v.y,
        cosp * v.y * v.z - v.x * sin,
        0.0f,
    };
    simd::float4 col2 = {
        cosp * v.x * v.z - v.y * sin,
        cosp * v.y * v.z + v.x * sin,
        cos + cosp * v.z * v.z,
        0.0f,
    };
    simd::float4 col3 = {
        0.0f,
        0.0f,
        0.0f,
        1.0f
    };
    simd::float4x4 result = {col0, col1, col2, col3};
    return result;
}

simd::float4x4 lyzzvs::rotationAround_xAxis(float angle) {
    static const simd::float3 xAxis = { 1, 0, 0 };
    return rotation(angle, xAxis);
}

simd::float4x4 lyzzvs::rotationAround_yAxis(float angle) {
    static const simd::float3 yAxis = { 0, 1, 0 };
    return rotation(angle, yAxis);
}

simd::float4x4 lyzzvs::rotationAround_zAxis(float angle) {
    static const simd::float3 zAxis = { 0, 0, 1 };
    return rotation(angle, zAxis);
}

simd::float4x4 lyzzvs::translate(simd::float4x4 matrix, float tx, float ty, float tz) {
    /*
     0   1   2   3
     4   5   6   7
     8   9   10 11
     12 13 14 15
     */
    simd::float4 col0 = {
        matrix.columns[0].x,
        matrix.columns[0].y,
        matrix.columns[0].z,
        matrix.columns[0].w
    };
    simd::float4 col1 = {
        matrix.columns[1].x,
        matrix.columns[1].y,
        matrix.columns[1].z,
        matrix.columns[1].w
    };
    simd::float4 col2 = {
        matrix.columns[2].x,
        matrix.columns[2].y,
        matrix.columns[2].z,
        matrix.columns[2].w
    };
    simd::float4 col3 = {
        matrix.columns[0].x * tx + matrix.columns[0].y * ty + matrix.columns[0].z * tz + matrix.columns[0].w,
        matrix.columns[1].x * tx + matrix.columns[1].y * ty + matrix.columns[1].z * tz + matrix.columns[1].w,
        matrix.columns[2].x * tx + matrix.columns[2].y * ty + matrix.columns[2].z * tz + matrix.columns[2].w,
        matrix.columns[3].x * tx + matrix.columns[3].y * ty + matrix.columns[3].z * tz + matrix.columns[3].w
    };
    simd::float4x4 result = {col0, col1, col2, col3};
    return result;
}

simd::float4x4 lyzzvs::matrixSetLookAt(
                                      float eyeX,      float eyeY,       float eyeZ,
                                      float centerX, float centerY, float centerZ,
                                      float upX,        float upY,        float upZ
                                      ) {
    /// lookat
    simd::float3 ev = { eyeX, eyeY, eyeZ };
    simd::float3 cv = { centerX, centerY, centerZ };
    simd::float3 uv = { upX, upY, upZ };
    /// 计算新定义的坐标轴基向量
    simd::float3 n = vector3Normalize(vector3Add(ev, vector3Negate(cv)));
    simd::float3 u = vector3Normalize(vector3CrossProduct(uv, n));
    simd::float3 v = vector3CrossProduct(n, u);
    
    /// 计算坐标转换矩阵
    /*
     1、先将👀平移动到世界坐标原点；
     2、旋转
     |u.x, u.y, u.z,0|      |1,0,0,-ev.x|    |u.x, u.y, u.z , -u*ev |
     |v.x, v.y, v.z,0|  *  |0,1,0,-ev.y| =  |v.x, v.y, v.z, -v*ev |
     |n.x, n.y, n.z,0|      |0,0,1,-ev.z|    |n.x, n.y, n.z, -n*ev  |
     |0,     0,    0,    1|      |0,0,0,1   |        |0,    0,     0,    1         |
     */
    simd::float4 cl0 = {
        u.x,
        v.x,
        n.x,
        0.0f
    };
    simd::float4 cl1 = {
        u.y,
        v.y,
        n.y,
        0.0f
    };
    simd::float4 cl2 = {
        u.z,
        v.z,
        n.z,
        0.0f
    };
    simd::float4 cl3 = {
        vector3DotProduct(vector3Negate(u), ev),
        vector3DotProduct(vector3Negate(v), ev),
        vector3DotProduct(vector3Negate(n), ev),
        1.0f
    };
    simd::float4x4 m = {
        cl0, cl1, cl2, cl3
    };
    return m;
}

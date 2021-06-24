#ifndef MATH_FUNCITONS_INCLUDED
#define MATH_FUNCITONS_INCLUDED

static const float maxFloat = 3.402823466e+38; 

// レイと球体の交差判定をし、(光線原点と近交点の距離, 両交点間の距離)を返す
// 交差がないなら、(maxFloat, 0)を返す
float2 intersectSphere(float3 rayOrigin, float3 rayDir, float3 center, float radius)
{
    float3 offset = rayOrigin - center;
    const float a = 1;
    float b = 2 * dot(offset, rayDir);
    float c = dot(offset, offset) - radius * radius;

    float discriminant = b * b - 4 * a*c;
    // discriminant < 0 : 交点なし
    // discriminant == 0 : 交点1つ
    // discriminant > 0 : 交点2つ
    if (discriminant > 0)
    {
        float s = sqrt(discriminant);
        float dstToNear = max(0, (-b - s) / (2 * a));
        float dstToFar = (-b + s) / (2 * a);

        if (dstToFar >= 0)
        {
            return float2(dstToNear, dstToFar - dstToNear);
        }
    }
    // 交点なし
    return float2(maxFloat, 0);
}

// レイと無限高さの円柱体の交差判定をし、(光線原点と近交点の距離, 両交点間の距離)を返す
// 交差がないなら、(maxFloat, 0)を返す
float2 intersectInfiniteCylinder(float3 rayOrigin, float3 rayDir, float3 cylinderOrigin, float3 cylinderDir, float cylinderRadius)
{
    float3 a0 = rayDir - dot(rayDir, cylinderDir) * cylinderDir;
    float a = dot(a0,a0);
 
    float3 dP = rayOrigin - cylinderOrigin;
    float3 c0 = dP - dot(dP, cylinderDir) * cylinderDir;
    float c = dot(c0,c0) - cylinderRadius * cylinderRadius;
 
    float b = 2 * dot(a0, c0);
 
    float discriminant = b * b - 4 * a * c;
    // discriminant < 0 : 交点なし
    // discriminant == 0 : 交点1つ
    // discriminant > 0 : 交点2つ
    if (discriminant > 0)
    {
        float s = sqrt(discriminant);
        float dstToNear = max(0, (-b - s) / (2 * a));
        float dstToFar = (-b + s) / (2 * a);
 
        if (dstToFar >= 0)
        {
            return float2(dstToNear, dstToFar - dstToNear);
        }
    }
    // 交点なし
    return float2(maxFloat, 0);
}

// レイと無限広さの平面の交差判定をし、(光線原点と交点の距離)を返す
// 平行の場合にmaxFloatを返す
float intersectInfinitePlane(float3 rayOrigin, float3 rayDir, float3 planeOrigin, float3 planeDir)
{
    float cos = dot(rayDir, planeDir);

    if (cos == 0)
    {
        // 平行
        return maxFloat;
    }

    float verticalDst = dot(rayOrigin, planeDir) - dot(planeOrigin, planeDir);
    return -verticalDst/cos;
}

// レイとディスク形の交差判定をし、(光線原点と交点の距離)を返す
float intersectDisc(float3 rayOrigin, float3 rayDir, float3 p1, float3 p2, float3 discDir, float discRadius, float innerRadius)
{
    float discDst = maxFloat;
    float2 cylinderIntersection = intersectInfiniteCylinder(rayOrigin, rayDir, p1, discDir, discRadius);
    float cylinderDst = cylinderIntersection.x;
 
    if(cylinderDst < maxFloat)
    {
        float finiteC1 = dot(discDir, rayOrigin + rayDir * cylinderDst - p1);
        float finiteC2 = dot(discDir, rayOrigin + rayDir * cylinderDst - p2);
 
        // Ray intersects with edges of the cylinder/disc
        if(finiteC1 > 0 && finiteC2 < 0 && cylinderDst > 0)
        {
            discDst = cylinderDst;
        }
        else
        {
            float radiusSqr = discRadius * discRadius;
            float innerRadiusSqr = innerRadius * innerRadius;
 
            float p1Dst = max(intersectInfinitePlane(rayOrigin, rayDir, p1, discDir), 0);
            float3 q1 = rayOrigin + rayDir * p1Dst;
            float p1q1DstSqr = dot(q1 - p1, q1 - p1);
 
            // Ray intersects with lower plane of cylinder/disc
            if(p1Dst > 0 && p1q1DstSqr < radiusSqr && p1q1DstSqr > innerRadiusSqr)
            {
                if(p1Dst < discDst)
                {
                    discDst = p1Dst;
                }
            }
                 
            float p2Dst = max(intersectInfinitePlane(rayOrigin, rayDir, p2, discDir), 0);
            float3 q2 = rayOrigin + rayDir * p2Dst;
            float p2q2DstSqr = dot(q2 - p2, q2 - p2);
 
            // Ray intersects with upper plane of cylinder/disc
            if(p2Dst > 0 && p2q2DstSqr < radiusSqr && p2q2DstSqr > innerRadiusSqr)
            {
                if(p2Dst < discDst)
                {
                    discDst = p2Dst;
                }
            }
        }
    }
     
    return discDst;
}

// vの値を元の範囲(minOld, maxOld)から新しい範囲(minNew, maxNew)に再配置する
float remap(float v, float minOld, float maxOld, float minNew, float maxNew)
{
    return minNew + (v - minOld) * (maxNew - minNew) / (maxOld - minOld);
}

// ディスクのUVを計算する
float2 discUV(float3 planarDiscPos, float3 discDir, float3 center, float radius)
{
    float3 planarDiscPosNorm = normalize(planarDiscPos);
    float sampleDist01 = length(planarDiscPos) / radius;

    float3 tangentTestVector = float3(1,0,0);
    if(abs(dot(discDir, tangentTestVector)) >= 1)
    {
        tangentTestVector = float3(0,1,0);
    }

    float3 tangent = normalize(cross(discDir, tangentTestVector));
    float3 biTangent = cross(tangent, discDir);
    float phi = atan2(dot(planarDiscPosNorm, tangent), dot(planarDiscPosNorm, biTangent)) / PI;
    phi = remap(phi, -1, 1, 0, 1);

    // Radial distance
    float u = sampleDist01;
    // Angular distance
    float v = phi;

    return float2(u,v);
}

// 座標回転
float3 RotateAboutAxis(float3 In, float3 Axis, float Rotation)
{
    float sin_R = sin(Rotation);
    float cos_R = cos(Rotation);
    float one_minus_cos = 1.0 - cos_R;
 
    Axis = normalize(Axis);
    float3x3 rot_mat = {
        one_minus_cos * Axis.x * Axis.x + cos_R, one_minus_cos * Axis.x * Axis.y - Axis.z * sin_R, one_minus_cos * Axis.z * Axis.x + Axis.y * sin_R,
        one_minus_cos * Axis.x * Axis.y + Axis.z * sin_R, one_minus_cos * Axis.y * Axis.y + cos_R, one_minus_cos * Axis.y * Axis.z - Axis.x * sin_R,
        one_minus_cos * Axis.z * Axis.x - Axis.y * sin_R, one_minus_cos * Axis.y * Axis.z + Axis.x * sin_R, one_minus_cos * Axis.z * Axis.z + cos_R
    };
    return mul(rot_mat, In);
}

#endif

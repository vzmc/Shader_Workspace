#ifndef COLOR_FUNCITONS_INCLUDED
#define COLOR_FUNCITONS_INCLUDED

// HDRのRGB色をLinear空間からGamma空間に変換する
// UnityCG.cginc内のLinearToGammaSpaceと同様
float3 LinearToGammaSpace (float3 linRGB)
{
    linRGB = max(linRGB, float3(0.f, 0.f, 0.f));
    // 参考 http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
}

// HDRのRGB色をLinear空間からGamma空間に変換する
// UnityCG.cginc内のGammaToLinearSpaceと同様
float3 GammaToLinearSpace (float3 sRGB)
{
    // 参考 http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return sRGB * (sRGB * (sRGB * 0.305306011f + 0.682171111f) + 0.012522878f);
}
 
// 参考 https://forum.unity.com/threads/how-to-change-hdr-colors-intensity-via-shader.531861/
float3 hdrIntensity(float3 emissiveColor, float intensity)
{
    // Gamma空間使ってないなら、まずLinear空間へ変換する
    #ifndef UNITY_COLORSPACE_GAMMA
    emissiveColor.rgb = LinearToGammaSpace(emissiveColor.rgb);
    #endif
    // 発光効果
    emissiveColor.rgb *= pow(2.0, intensity);
    // Gamma空間使ってないなら、最後にLinear空間に戻す
    #ifndef UNITY_COLORSPACE_GAMMA
    emissiveColor.rgb = GammaToLinearSpace(emissiveColor.rgb);
    #endif
 
    return emissiveColor;
}
 
// Based upon Unity's shadergraph library functions
float3 RGBToHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
 
// Based upon Unity's shadergraph library functions
float3 HSVToRGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

#endif

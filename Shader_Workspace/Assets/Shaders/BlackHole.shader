Shader "MyURP/BlackHole"
{
    Properties
    {
        _DiscTex ("Disc texture", 2D) = "white" {}
        _DiscWidth ("Width of the accretion disc", float) = 0.1
        _DiscOuterRadius ("Object relative outer disc radius", Range(0,1)) = 1
        _DiscInnerRadius ("Object relative disc inner radius", Range(0,1)) = 0.25
        _DiscSpeed ("Disc rotation speed", float) = 2
        [HDR]_DiscColor ("Disc main color", Color) = (1,0,0,1)
        _DopplerBeamingFactor ("Doppler beaming effect factor", float) = 66
        _HueRadius ("Hue shift start radius", Range(0,1)) = 0.75
        _HueShiftFactor ("Hue shifting factor", float) = -0.03
        _Steps ("Amount of steps", int) = 256
        _StepSize ("Step size", Range(0.001, 1)) = 0.1
        _SSRadius ("Object relative Schwarzschild radius", Range(0,1)) = 0.2
        _GConst ("Gravitational constant", float) = 0.15
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS	: POSITION;
            };

            struct Varyings
            {
                float4 positionCS	: SV_POSITION;
                float3 positionWS	: TEXCOORD0;

                float3 center		: TEXCOORD1;
                float3 objectScale	: TEXCOORD2;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                // オブジェクトの中心座標とスケールを取得
                OUT.center = UNITY_MATRIX_M._m03_m13_m23;
                OUT.objectScale = float3(length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x)),
                                         length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y)),
                                         length(float3(UNITY_MATRIX_M[0].z, UNITY_MATRIX_M[1].z, UNITY_MATRIX_M[2].z)));

                return OUT;
            }

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_DiscTex);
                SAMPLER(sampler_DiscTex);
                float _DiscWidth;
                float _DiscOuterRadius;
                float _DiscInnerRadius;
                float4 _DiscTex_ST;
                float _DiscSpeed;
                float4 _DiscColor;
                float _DopplerBeamingFactor;
                float _HueRadius;
                float _HueShiftFactor;
                int _Steps;
                float _StepSize;
                float _SSRadius;
                float _GConst;
            CBUFFER_END

            #include "Assets/Shaders/MathFunctions.hlsl"
            #include "Assets/Shaders/ColorFunctions.hlsl"

            float3 discColor(float3 baseColor, float3 planarDiscPos, float3 discDir, float3 cameraPos, float u, float radius)
            {
                float3 newColor = baseColor;

                // Distance intensity fall-off
                float intensity = remap(u, 0, 1, 0.5, -1.2);
                intensity *= abs(intensity);

                // Doppler beaming intensity change
                float3 rotatePos = RotateAboutAxis(planarDiscPos, discDir, 0.01);
                float dopplerDistance = (length(rotatePos - cameraPos) - length(planarDiscPos - cameraPos)) / radius;
                intensity += dopplerDistance * _DiscSpeed * _DopplerBeamingFactor;

                newColor = hdrIntensity(baseColor, intensity);

                // Distance hue shift
                float3 hueColor = RGBToHSV(newColor);
                float hueShift = saturate(remap(u, _HueRadius, 1, 0, 1));
                hueColor.r += hueShift * _HueShiftFactor;
                newColor = HSVToRGB(hueColor);

                return newColor;
            }

            float4 frag (Varyings IN) : SV_Target
            {
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDir = normalize(IN.positionWS - _WorldSpaceCameraPos);

                float sphereRadius = 0.5 * min(min(IN.objectScale.x, IN.objectScale.y), IN.objectScale.z);
                float2 outerSphereIntersection = intersectSphere(rayOrigin, rayDir, IN.center, sphereRadius);

                // Disc information, direction is objects rotation
                float3 discDir = normalize(mul(unity_ObjectToWorld, float4(0,1,0,0)).xyz);
                float3 p1 = IN.center - 0.5 * _DiscWidth * discDir;
                float3 p2 = IN.center + 0.5 * _DiscWidth * discDir;
                float discRadius = sphereRadius * _DiscOuterRadius;
                float innerRadius = sphereRadius * _DiscInnerRadius;

                // Raymarching information
                float transmittance = 0;
                float blackHoleMask = 0;
                float3 samplePos = float3(maxFloat, 0, 0);

                float3 currentRayPos = rayOrigin + rayDir * outerSphereIntersection.x;
                float3 currentRayDir = rayDir;

                // レイが引力範囲の球体と交差があったら
                if(outerSphereIntersection.x < maxFloat)
                {
                    for (int i = 0; i < _Steps; i++)
                    {
                        float3 dirToCenter = IN.center-currentRayPos;
                        float dstToCenter = length(dirToCenter);
                        dirToCenter /= dstToCenter;
                
                        if(dstToCenter > sphereRadius + _StepSize)
                        {
                            break;
                        }

                        // 引力でレイの方向を変える
                        float force = _GConst / (dstToCenter * dstToCenter);
                        currentRayDir = normalize(currentRayDir + dirToCenter * force * _StepSize);

                        // レイを前進させる
                        currentRayPos += currentRayDir * _StepSize;

                        float blackHoleDistance = intersectSphere(currentRayPos, currentRayDir, IN.center, _SSRadius * sphereRadius).x;
                        if(blackHoleDistance <= _StepSize)
                        {
                            blackHoleMask = 1;
                            break;
                        }

                        // Check for disc intersection nearby
                        float discDst = intersectDisc(currentRayPos, currentRayDir, p1, p2, discDir, discRadius, innerRadius);
                        if(transmittance < 1 && discDst < _StepSize)
                        {
                            transmittance = 1;
                            samplePos = currentRayPos + currentRayDir * discDst;
                            break;
                        }
                    }
                }

                float2 uv = float2(0,0);
                float3 planarDiscPos = float3(0,0,0);
                if(samplePos.x < maxFloat)
                {
                    planarDiscPos = samplePos - dot(samplePos - IN.center, discDir) * discDir - IN.center;
                    uv = discUV(planarDiscPos, discDir, IN.center, discRadius);
                    uv.y += _Time.x * _DiscSpeed;
                }
                float texCol = SAMPLE_TEXTURE2D(_DiscTex, sampler_DiscTex, uv * _DiscTex_ST.xy).r;

                float2 screenUV = IN.positionCS.xy / _ScreenParams.xy;

                // 曲げられたレイでscreenUVを計算する
                float3 distortedRayDir = currentRayDir;
                float4 rayCameraSpace = mul(unity_WorldToCamera, float4(distortedRayDir,0));
                float4 rayUVProjection = mul(unity_CameraProjection, float4(rayCameraSpace));
                float2 distortedScreenUV = rayUVProjection.xy * 0.5 + 0.5;
                
                // 歪みられた空間の縁側をぼやける
                float edgeFadex = smoothstep(0, 0.25, 1 - abs(remap(screenUV.x, 0, 1, -1, 1)));
                float edgeFadey = smoothstep(0, 0.25, 1 - abs(remap(screenUV.y, 0, 1, -1, 1)));
                float t = saturate(remap(outerSphereIntersection.y, sphereRadius, 2 * sphereRadius, 0, 1)) * edgeFadex * edgeFadey;
                distortedScreenUV = lerp(screenUV, distortedScreenUV, t);

                // screenUV
                float3 backgroundCol = SampleSceneColor(distortedScreenUV) * (1 - blackHoleMask);

                float3 discCol = discColor(_DiscColor.rgb, planarDiscPos, discDir, _WorldSpaceCameraPos, uv.x, discRadius);

                transmittance *= texCol * _DiscColor.a;
                float3 col = lerp(backgroundCol, discCol, transmittance);
                return float4(col, 1);
            }

            ENDHLSL
        }
    }
}

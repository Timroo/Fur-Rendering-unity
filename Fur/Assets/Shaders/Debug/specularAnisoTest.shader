Shader "Unlit/specularAnisoTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        // 各向异性
        _AnisoBias ("Anisotropic Bias", Range(-1, 1)) = 0.0 // 切线偏移
        _AnisoExponent ("Anisotropic Exponent", Range(1, 100)) = 20 // 各向异性锐度
        _AnisoStrength ("Anisotropic Strength", Range(0, 1)) = 0.5 // 各向异性强度
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 Normal:NORMAL;
                float3 Tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;

            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.Normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldTangent = UnityObjectToWorldDir(v.Tangent);
                return o;
            }

            float _AnisoBias;
            float _AnisoExponent;
            float _AnisoStrength;

            float3 TShift(float3 tangent, float3 normal, float bias)
            {
                // tangent：发丝方向；normal：表面法线；bias：切线偏移程度的系数

                // 作用：发丝方向 沿着法线方向偏移一定距离；模拟光线散射距离
                return normalize(tangent + bias * normal);
            }

            // - Kajiya-Kay
            // - 毛发材质各向异性高光
            float StrandSpecular(fixed3 T, fixed3 V, fixed3 L, fixed exponent)
            {
                // T:顺着发丝方向; V:实现方向; L:光线方向; exponent:各向异性锐度（越大高光越细）
                float3 H = normalize(L + V);                // 半角向量
                float TdotH = dot(T, H);                    // 发丝方向和半角的点积
                float sinTH = sqrt(1 - TdotH * TdotH);      // 垂直分量   s^2+c^2 = 1
                float dirAtten = smoothstep(-1, 0, TdotH);  // 方向衰减:光线和视线在发丝两侧
                return dirAtten * pow(sinTH, exponent);     // 最终高光计算
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 worldTangent = normalize(i.worldTangent);
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldBitangent = normalize(cross(worldNormal, worldTangent));
                fixed3 worldView = normalize(_WorldSpaceCameraPos - i.worldPos);
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);

                fixed3 biasTangent = TShift(worldBitangent, worldNormal, _AnisoBias);
                float anisoSpec = StrandSpecular(biasTangent, worldView, worldLight, _AnisoExponent);

                
                // return fixed4(biasTangent, 1);
                return anisoSpec * _AnisoStrength;
            }
            ENDCG
        }
    }
}

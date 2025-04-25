Shader "FurShader/_FurShellShader"
{
    Properties
    {
        //基本颜色
        _MainTex ("Texture", 2D) = "white" { }
        _Color ("FurColor", Color) = (1, 1, 1, 1)
        _RootColor ("FurRootColor", Color) = (0.5, 0.5, 0.5, 1)

        //光照
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Shininess ("Shininess", Range(0.01, 256.0)) = 8.0       
        _RimColor ("Rim Color", Color) = (0, 0, 0, 1)
        _RimPower ("Rim Power", Range(0.0, 8.0)) = 6.0
        // 各向异性
        _AnisoBias ("Anisotropic Bias", Range(-1, 1)) = 0.0 // 切线偏移
        _AnisoExponent ("Anisotropic Exponent", Range(1, 100)) = 20 // 各向异性锐度
        _AnisoStrength ("Anisotropic Strength", Range(0, 1)) = 0.5 // 各向异性强度

        //毛发参数
        _FurTex ("Fur Pattern", 2D) = "white" { }     
        _FurLength ("Fur Length", Range(0.0, 1)) = 0.5
        _RootStrength ("Root Strength", Range(0.0, 1)) = 0.25

        _FurFlowMap ("Fur Flow Map", 2D) = "white" { }

    }
    SubShader
    {
        Tags {  "RenderType" = "Transparent" 
                "IgnoreProjector" = "True" 
                "Queue" = "Transparent" }
        Cull Off
        ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #include "Lighting.cginc"   
            #include "UnityCG.cginc"

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            
            sampler2D _MainTex;
            half4 _MainTex_ST; 
            fixed4 _Color;
            fixed4 _RootColor;
            fixed4 _Specular;
            fixed _Shininess;

            sampler2D _FurTex;
            half4 _FurTex_ST;

            half4 _SubTex_ST;   // 次级缩放
            fixed _FurLength;
            fixed _RootStrength;

            float3 _ForceOffset;

            fixed4 _RimColor;
            half _RimPower;

            float _LayerOffset;

            sampler2D _FurFlowMap;// flowmap指导顶点位移
            float4 _UVoffset;   // uv偏移

            // 环境光遮蔽
            fixed4 _OcclusionColor;
            float _AOStrength;

            // 光线穿透
            float _FurTransmissionIntensity;
            float _FurDirLightExposure;
            fixed4 _DirLightColor;

            // 各向异性高光
            float _AnisoBias;      // 切线偏移
            float _AnisoExponent;   // 各向异性锐度
            float _AnisoStrength;   // 各向异性强度
            
            struct a2v{
                float4 vertex : POSITION;   
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 texcoord2 : TEXCOORD1;
                float4 tangent : TANGENT;
                
            };

            struct v2f{
                float4 pos : SV_POSITION;
                half4 uv: TEXCOORD0;
                float3 worldNormal: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
                float3 flow : TEXCOORD3;
                float3 worldTangent : TEXCOORD4;
            };

            v2f vert(a2v v){
                v2f o;
                
                // 顶点外扩 = 法线 * 每层外扩距离 * 长度
                float3 offsetVertex = v.vertex.xyz + v.normal * _LayerOffset * _LayerOffset * _FurLength;
                
                // flowmap指导受力偏移 - （仅供测试，一般不用）
                // 切线空间- 模型空间
                // float3 N = normalize(v.normal);
                // float3 T = normalize(v.tangent);
                // float3 B = normalize(cross(N, T));
                // float3x3 TBN = float3x3 (T, B, N);
                // float3 flowSam = tex2Dlod(_FurFlowMap, float4(v.texcoord.xy, 0, 0)).rgb * 2 - 1; // 映射到[-1,1]
                // float3 flowVec = float3(flowSam.x, 0, flowSam.z);
                // offsetVertex += mul(TBN,flowVec) * _LayerOffset ;

                // 顶点受力偏移
                offsetVertex += mul(unity_WorldToObject, _ForceOffset);

                
                float2 uvoffset = _UVoffset.xy * _LayerOffset * 0.1;
    
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex) * _SubTex_ST.xy + uvoffset  ;  //纹理uv
                o.uv.zw = TRANSFORM_TEX(v.texcoord2, _FurTex) * _SubTex_ST.xy + uvoffset ;  //噪声uv
                // o.uv.zw = TRANSFORM_TEX(v.texcoord2, _FurTex)  ;  //噪声uv

                o.pos = UnityObjectToClipPos(float4(offsetVertex, 1));
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldTangent = normalize(UnityObjectToWorldDir(v.tangent.xyz));

                return o;
            }

            // 各向异性高光
            // - 控制头发高光的走向
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

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 worldHalf = normalize(worldView + worldLight);

                fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
                // 环境光遮蔽（AO）
                half Occlusion = _LayerOffset * _LayerOffset * _AOStrength;
                Occlusion += 0.02; // 避免过暗
                fixed3 AO = lerp(_OcclusionColor.rgb * albedo, albedo, Occlusion);

                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * AO;

                // 边缘光
                half vdotn = 1.0 - saturate(max(0, dot(worldView, worldNormal)));
                fixed3 rim = _RimColor.rgb * _RimColor.a * saturate(1 - pow(1 - vdotn, _RimPower));  // 边缘光效果

                // 漫反射 - 光线穿透改进
                fixed3 ldotn = dot(worldNormal, worldLight);
                half DirLight = saturate (ldotn + _FurTransmissionIntensity +  _LayerOffset); // 毛发穿透效果
                DirLight *= _FurDirLightExposure * _DirLightColor.rgb;
                fixed3 diffuse = _LightColor0.rgb * albedo * DirLight;
                // fixed3 diffuse = _LightColor0.rgb * albedo * ldotn;

                // 高光
                fixed3 ndoth = saturate(dot(worldNormal, worldHalf));
                fixed3 specularPhong = _LightColor0.rgb * _Specular.rgb * pow(saturate(ndoth), _Shininess);

                // 各向异性高光
                fixed3 worldBitangent = normalize(cross(worldNormal, normalize(i.worldTangent))); // 副切线：旋转90°
                fixed3 shiftedTangent = TShift(worldBitangent, worldNormal, _AnisoBias);
                float anisoSpec = StrandSpecular(shiftedTangent, worldView, worldLight, _AnisoExponent);
                fixed3 specularAniso = _LightColor0.rgb * _Specular.rgb * anisoSpec * _AnisoStrength;

                // 合并高光（Phong + Anisotropic）
                fixed3 specular = specularPhong + specularAniso;

                // 颜色合并
                fixed3 color = ambient + diffuse + specular + rim;
                color = lerp(_RootColor,color,saturate(pow( _LayerOffset,_RootStrength)));

                // 毛发透明度
                fixed3 noise = tex2D(_FurTex, i.uv.zw ).rgb;
                fixed alpha = saturate(noise - (_LayerOffset * _LayerOffset));
                
                return fixed4(color, alpha);
                // return fixed4(specularAniso, alpha); // 测试各向异性高光
            }

           
            ENDCG
        }
    }
}

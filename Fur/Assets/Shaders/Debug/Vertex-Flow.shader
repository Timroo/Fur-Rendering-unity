Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 tangent : TANGENT;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 color : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                float3 T = normalize(v.tangent.xyz);  // 切线
                float3 N = normalize(v.normal.xyz);   // 法线
                float3 B = normalize(cross(T, N)); // 副切线
                float3x3 TBN = float3x3(T, B, N);
                float3 flowSam = tex2Dlod(_MainTex, float4(v.uv, 0, 0)).rgb * 2 - 1; // 映射到[-1,1]
                float3 flowVec = float3(flowSam.x, 0, flowSam.z);

                o.color = mul(TBN,flowVec);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 color = tex2D(_MainTex, i.uv).rgb;
                // 片元着色器颜色
                // return fixed4(color,1);
                // 顶点着色器颜色
                return fixed4(i.color,1);
            }
            ENDCG
        }
    }
}

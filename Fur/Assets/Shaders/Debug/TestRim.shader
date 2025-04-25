Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RimColor ("RimColor", Color) = (1,1,1,1)
        _RimPower("RimPower", Range(0, 10)) = 1
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 Normal:NORMAL;
            };

            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.Normal = UnityObjectToWorldNormal(v.Normal);
                return o;
            }

            fixed4 _RimColor;
            float _RimPower;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float vdotn = dot(normalize(i.Normal), worldView);
                
                fixed3 rim = _RimColor.rgb * _RimColor.a * saturate(  1- pow(vdotn, _RimPower));  // 边缘光效果

                return fixed4(rim,1);
            }
            ENDCG
        }
    }
}

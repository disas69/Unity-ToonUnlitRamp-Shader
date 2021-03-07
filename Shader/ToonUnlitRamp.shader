Shader "Custom/ToonUnlitRamp"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _MainColor("Main Color", Color) = (1,1,1,1)
        [HDR] _AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)
        [HDR] _SpecularColor("Specular Color", Color) = (0.9,0.9,0.9,1)
        _SpecularPower("Specular Power", Float) = 32
        _RampSize("Ramp Size", Range(0, 1)) = 0.65
        _RampsCount("Ramps Count", Range(1, 10)) = 1
        _MinIntensity("Min Intensity", Range(0, 1)) = 0.25
        _MaxIntensity("Max Intensity", Range(0, 1)) = 1
        [HDR] _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimRange("Rim Range", Range(0, 1)) = 0.1
        _RimPower("Rim Power", Range(0, 1)) = 0.25
    }
    SubShader
    {
        Pass
        {
            Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" "PassFlags" = "OnlyDirectional" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            
            #include "UnityCG.cginc" 
            #include "Lighting.cginc" 
            #include "AutoLight.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 worldNormal : NORMAL;
                float3 viewDir : TEXCOORD1;
                SHADOW_COORDS(2)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _MainColor;
            float4 _AmbientColor;
            float4 _SpecularColor;
            float _SpecularPower;
            half _RampSize;
            half _RampsCount;
            half _MinIntensity;
            half _MaxIntensity;
            fixed4 _RimColor;
            half _RimRange;
            half _RimPower;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                TRANSFER_SHADOW(o)
                return o;
            }

            inline half LightingToonRamp(float intensity)
            {
                float3 ramp = 1;
                half rampsCount = floor(_RampsCount);

                if (intensity <= 0) {
                    ramp = clamp(_MinIntensity, 0, _MaxIntensity);
                }
                else if (intensity > _RampSize) {
                    ramp = clamp(_MaxIntensity, _MaxIntensity, 1);
                }
                else {
                    half step = _RampSize / rampsCount;
                    half colorStep = clamp((_MaxIntensity - _MinIntensity), 0, 1) / (rampsCount + 1);

                    for (int i = 0; i < rampsCount; i++)
                    {
                        if ((step * (i + 1)) >= intensity) {
                            ramp = clamp(_MinIntensity + colorStep * (i + 1), _MinIntensity, _MaxIntensity);
                            break;
                        }
                    }
                }

                return ramp;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 color = tex2D(_MainTex, i.uv) * _MainColor;

                float3 normal = normalize(i.worldNormal);
                float NdotL = dot(_WorldSpaceLightPos0, normal);
                float lightIntensity = NdotL * (SHADOW_ATTENUATION(i) > 0 ? 1 : 0);
                float4 light = LightingToonRamp(lightIntensity) * _LightColor0;

                float3 viewDir = normalize(i.viewDir);
                float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
                float NdotH = dot(normal, halfVector);
                float specularIntensity = pow(NdotH * lightIntensity, _SpecularPower * _SpecularPower);
                float specular = smoothstep(0.005, 0.01, specularIntensity) * _SpecularColor;

                float4 rimDot = 1 - dot(viewDir, normal);
                float rimIntensity = smoothstep(_RimRange - 0.01, _RimRange + 0.01, rimDot * pow(NdotL, _RimPower));
                float4 rim = rimIntensity * _RimColor;

                return color * (light + specular + rim + _AmbientColor);
            }
            ENDCG
        }

        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f {
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}
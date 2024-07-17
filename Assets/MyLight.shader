Shader "LG/MyLight"
{
    Properties
    {
        _Tint("Tint", Color) = (1, 1, 1, 1)
        _MainTex("Main Texture", 2D) = "white" {}
        _SpecColor("Specular Color", Color) = (1, 1, 1, 1) // 스페큘러 색상
        _SpecPower("Specular Power", Range(1, 128)) = 32 // 스펙큘러의 강도 - POW가 클수록 하이라이트 범위가 줄어듬
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // 라이팅 함수들이 들어있음
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex MyVert
            #pragma fragment MyFrag
            float4 _Tint;
            Texture2D _MainTex;
            SamplerState sampler_MainTex;
            float4 _SpecColor;
            float _SpecPower;

            struct VertexData
            {
                float3 position : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            // TEXCOORD1, 2등 TEXCOORD 채널들을 꼭 UV 채널용으로만 사용할 필요는 없다!
            struct FragmentData
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0; // UV 채널
                float3 normal : TEXCOORD1; // 월드 노말을 저장
                float3 worldPos : TEXCOORD2; // 월드 포지션을 저장
            };

            FragmentData MyVert(VertexData input)
            {
                FragmentData output;
                output.position = TransformObjectToHClip(input.position);
                output.worldPos = TransformObjectToWorld(input.position);
                output.normal = TransformObjectToWorldNormal(input.normal); // 오브젝트 노말을 월드 노말로 변환
                output.uv = input.uv;
                return output;
            }

            float4 MyFrag(FragmentData input) : SV_Target
            {
                float3 albedo = _MainTex.Sample(sampler_MainTex, input.uv) * _Tint;

                // 라이트 정보를 가져옴
                Light light = GetMainLight();
                float3 lightDir = light.direction;
                float3 lightColor = light.color;

                // 뷰 방향을 가져옴 (_WorldSpaceCameraPos는 월드 카메라 위치)
                float3 viewDir = normalize(_WorldSpaceCameraPos - input.worldPos);

                // 램버트 라이트
                // 라이트 방향과 표면의 방향이 일치할수록 밝음 -> 두 벡터를 내적해서 1에 가까울수록 밝게하면됨
                float NdotL = saturate(dot(input.normal, lightDir));
                float3 lambert = NdotL * lightColor;

                // 블린 퐁
                // 1. 뷰와 라이트 벡터의 중간 벡터를 구하기
                // 2. 중간 벡터와 노말 벡터의 내적한 값이 1에 가까울수록 하이라이트가 강하다
                float3 halfDir = normalize(lightDir + viewDir);
                float3 NdotH = saturate(dot(input.normal, halfDir));
                // _SpecPower가 크면 클수록 pow(NdotH, _SpecPower) 값이 작아져서 -> 하이라이트 범위가 줄어든다
                float3 specular = _SpecColor.rgb * pow(NdotH, _SpecPower);
                
                float3 finalColor = albedo * (lambert + specular);
                return float4(finalColor, 1);
            }
            ENDHLSL
        }
        
    }
}

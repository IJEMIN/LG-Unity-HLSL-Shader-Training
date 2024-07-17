Shader "LG/TextureBlend"
{
    // 머티리얼 프로퍼티. 머티리얼에서 셰이더 유니폼 변수들에게 값을 전달할 수 있도록 함 
    Properties
    {
        _MainTexture("Main Texture", 2D) = "white" {} // 중괄호 {}는 현재는 사용하지 않지만, 과거 호환 때문에 셰이더 랩 파서가 필요로 함
        _BlendTexture("Blend Texxture", 2D) = "white" {}
        _BlendFactor("Blend Factor", Range(0, 1)) = 1 // Range()는 범위 제한을 건 Float
        // KeywordEnum을 사용하여 멀티 컴파일 키워드를 활성화하는 드롭다운 버튼 구현
        [KeywordEnum(Add, Subtract, Multiply, Overlay)]_BlendMode("Blend Mode", Float) = 0
    }
    
    // 하나의 셰이더는 여러 서브 셰이더를 가질 수 있음. 가장 먼저 호환되는 것이 사용됨 
    SubShader
    {
        // 하나의 서브 셰이더 내에 다수의 패스가 존재할 수 도 있음(외곽선 효과 등 여러번 그리기가 필요한 이펙트를 구현하는 경우)
        Pass
        {
            // HLSL 코드를 삽입하는 블록
            HLSLPROGRAM
            // URP 셰이더 사용시 가장 기본이 되는 라이브러리
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #pragma vertex vert // 버텍스 함수 이름 결정
            #pragma fragment frag // 프래그 먼트 함수 이름 결정
            // 멀티 컴파일을 통해 각 키워드에 대응되는 파생형 셰이더들인 셰이더 베리언트들을 만듬
            // KeywordEnum에 정의된 키워드들을 사용하여 각각의 셰이더 베리언트를 만듬
            #pragma multi_compile _BLENDMODE_ADD _BLENDMODE_SUBTRACT _BLENDMODE_MULTIPLY _BLENDMODE_OVERLAY

            // 유니폼 변수 : 버텍스 셰이더와 프래그먼트 셰이더가 공유하는 변수
            Texture2D _MainTexture; // 텍스처 오브젝트
            SamplerState sampler_MainTexture; // 해당 텍스처 오브젝트를 어떻게 샘플링 할것인가에 대한 샘플러 상태 오브젝트

            Texture2D _BlendTexture;
            SamplerState sampler_BlendTexture;

            // 원본과 블랜드 결과물 사이를 블랜드를 얼마나 할지 결정
            float _BlendFactor; 

            // 버텍스 입력 구조체
            // 시맨틱을 사용하기 때문에 필드(변수) 이름은 중요하지 않음
            // 시맨틱을 사용하면 그래픽스 드라이버가 이 필드가 무엇을 표현하는지 알수 있음
            struct VertextInput
            {
                float3 vertex : POSITION; // 버텍스의 위치를 나타내는 시맨틱을 사용
                float2 uv : TEXCOORD0; // 첫번째 UV 채널을 나타내는 시멘틱 사용
            };

            // 프래그먼트 입력 구조체
            struct FragmentInput
            {
                float4 positionHCS : SV_POSITION; // 클립 공간 또는 화면 공간을 나타내는 시맨틱 사용
                float2 uv : TEXCOORD0; // 첫번째 UV 채널을 나타내는 시멘틱 사용
            };

            // 버텍스 셰이더 - 오브젝트 공간 정점을 클립 공간 정점으로 변환
            FragmentInput vert(VertextInput input)
            {
                FragmentInput output;
                // 동차 클립 공간(Homogeneous Clip Space)로 변환
                output.positionHCS = TransformObjectToHClip(input.vertex);
                output.uv = input.uv;
                return output;
            }

            // 버텍스 함수를 거쳐 클립 공간으로 변환 -> 래스터라이저를 거쳐 화면 공간으로 변환 및 보간 -> 프래그먼트 함수로 전달

            // 프래그먼트 함수 - 픽셀의 색상을 계산
            half4 frag(FragmentInput input) : SV_Target // SV_Target -> 첫번째 렌더 타겟(메인 렌더 타겟)에 쓰기
            {
                // 텍스처 샘플링
                half4 baseColor = _MainTexture.Sample(sampler_MainTexture, input.uv);
                half4 blendColor = _BlendTexture.Sample(sampler_BlendTexture, input.uv);

                half4 result = half4(0, 0, 0, 0);
                // if문 대신에 전처리기 #if로 멀티 컴파일을 사용하여 블랜드 모드를 선택
                // 이는 셰이더 베리언트들을 만들기 때문에 계산 성능은 뛰어날수 있어도 셰이더 크기가 커질 수 있음
                #if defined(_BLENDMODE_ADD)
                result = baseColor + blendColor;
                #elif defined(_BLENDMODE_SUBTRACT)
                result = baseColor - blendColor;
                #elif defined(_BLENDMODE_MULTIPLY)
                result = baseColor * blendColor;
                #elif defined(_BLENDMODE_OVERLAY) // 오버레이는 밝은 부분은 더 밝게 어두운 것은 더 어둡게 하여 대조비를 강하게 함
                result.rgb = baseColor.rgb < 0.5 ?
                    2.0 * baseColor.rgb * blendColor.rgb
                    : 1 - 2 * (1.0 - baseColor.rgb) * (1.0 - blendColor.rgb);
                #endif

                result.a = baseColor.a;
                result = lerp(baseColor, result, _BlendFactor); // lerp() 함수를 사용하여 원본과 블랜드 결과물 사이를 섞음
                return result;
            }
            
            ENDHLSL
        }
    }
}
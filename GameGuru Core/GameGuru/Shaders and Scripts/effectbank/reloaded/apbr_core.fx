
#define PI 3.1415926535897932384626433832795f
#define GAMMA 2.2f                                                                                                                    
#include "constantbuffers.fx"
#include "settings.fx"     

#ifdef USEPARALLAXMAPPING
	float 	ShadowStrength = 0.5f;
#endif
#include "cascadeshadows.fx"

#define mSunColor (float3(1.0,1.0,1.0))

#define K_MODEL_SCHLICK 0
#define K_MODEL_CRYTEK 1
#define K_MODEL_DISNEY 0
#define K_MODEL_PE 1

// Global constants passed in
float4x4 WorldViewProjection : WorldViewProjection;
float4 eyePos : CameraPosition;
float4 ScrollScaleUV = { 0, 0, 2, 2 };
float4 HighlightCursor = {0.0f,0.0f,0.0f,1.0f};
float4 HighlightParams = {0.0f,0.0f,0.0f,1.0f};
float4 GlowIntensity = float4(0,0,0,0);
float AlphaOverride = 1.0f;
float SpecularOverride = 1.0f;
float4 EntityEffectControl = {0.0f, 0.0f, 0.0f, 0.0f}; // X=Alpha Slice Y=not used
float4 ArtFlagControl1 = {0.0f, 0.0f, 0.0f, 0.4f}; // X=Invert Normal (off by default) Y=Preserve Tangents (off by default) Z=DiffuseBoost W=ParallaxStrength
float4 ShaderVariables = float4(0,0,0,0);
float4 AmbiColorOverride = {1.0f, 1.0f, 1.0f, 1.0f};
float4 clipPlane : ClipPlane;
float SurfaceSunFactor = 1.0f;
float GlobalSpecular = 1.0f;
float GlobalSurfaceIntensity = 1.0f;
float4 SkyColor = {0,0,0,0};
float4 FloorColor = {0,0,0,0};
float4 DistanceTransition = {0,0,0,0};
float4 AmbiColor = {0.1f, 0.1f, 0.1f, 1.0f};
float4 SurfColor = {1.0f, 1.0f, 1.0f, 1.0f};
#ifdef ENABLE_PULSE_HIGHLIGHTING
	//float sintime : SinTime;
	float time : Time;
#endif

// Dynamic lights system
float4 SpotFlashPos;
float4 SpotFlashColor;
float4 HudFogColor = {0.0f, 0.0f, 0.0f, 0.0000001f};
float4 HudFogDist = {1.0f, 0.0f, 0.0f, 0.0000001f};
float4 g_lights_data;
float4 g_lights_pos0;
float4 g_lights_pos1;
float4 g_lights_pos2;
float4 g_lights_atten0;
float4 g_lights_atten1;
float4 g_lights_atten2;
float4 g_lights_diffuse0;
float4 g_lights_diffuse1;
float4 g_lights_diffuse2;

float dl_lights;
float dl_lightsVS;
float4 dl_pos[82];
float4 dl_diffuse[82];
float4 dl_angle[82];

float TotalSpecular = 1.0f;

#ifdef WITHANIMATION
 float4x4 boneMatrix[170] : BoneMatrixPalette;
#endif

#ifdef WITHCHARACTERCREATORMASK
 float4 ColorTone[4] = {
   float4(-1.0f, 1.0f, 1.0f, 1.0f),
   float4(-1.0f, 1.0f, 1.0f, 1.0f),
   float4(-1.0f, 1.0f, 1.0f, 1.0f),
   float4(-1.0f, 1.0f, 1.0f, 1.0f)
 };
 float ToneMix[4] = {
   float(0.5f),
   float(0.5f),
   float(0.5f),
   float(0.5f)
 };
#endif

#ifdef PBRVEGETATION
 float GrassFadeDistance = 10000.0f;
 #ifndef ENABLE_PULSE_HIGHLIGHTING
 float time: Time;
 #endif
 float SwayAmount = 0.05f;
 float SwaySpeed = 1.0f;
 float ScaleOverride = 2.5f;
#endif

struct appdata
{
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float2 uv           : TEXCOORD0;
	#ifdef LIGHTMAPPED
	 float2 uv2          : TEXCOORD1;
	#endif
	#ifdef PBRVEGETATION
	#else
	 #ifdef PBRTERRAIN
	  float2 uv2          : TEXCOORD1;
	 #else
	  float3 tangent      : TANGENT0;
	  float3 binormal     : BINORMAL0;
	  #ifdef WITHANIMATION
	   #ifdef WITHANIMATION8BONE
	    float4 Blendweight       : TEXCOORD1;
	    float4 Blendindices      : TEXCOORD2;   
	    float4 BlendweightExtra  : TEXCOORD3;
	    float4 BlendindicesExtra : TEXCOORD4;   
	   #else
	    float4 Blendweight  : TEXCOORD1;
	    float4 Blendindices : TEXCOORD2;   
	   #endif
	  #endif
	 #endif
	#endif
};

struct VSOutput
{
	float4 positionCS     : POSITION;
	float3 cameraPosition : TEXCOORD0;
	float4 position       : TEXCOORD1;
	float3 normal         : TEXCOORD2;
	float2 uv             : TEXCOORD3;
	#ifndef PBRVEGETATION
	float3 binormal       : TEXCOORD4;
 	float3 tangent        : TEXCOORD5;
	#endif
	float4 color         : TEXCOORD6;
	float viewDepth      : TEXCOORD7;
	float clip           : TEXCOORD8;
	#ifdef LIGHTMAPPED
	 float2 uv2           : TEXCOORD9;
	 float3 VertexLight    : TEXCOORD10;
	#else
	 float3 VertexLight    : TEXCOORD9;
	#endif
};


float3 CalcExtSpot( float3 worldNormal, float3 worldPos , float3 SpotPos , float3 SpotColor , float range, float3 angle,float3 diffusemap)
{
    float conewidth = 24;
	float toLight = length(SpotPos.xyz - worldPos) * 2.0;
	float4 local_lights_atten = float4(1.0, 1.0/range, 1.0/(range*range), 0.0);
	float intensity = 1.0/dot( local_lights_atten, float4(1,toLight,toLight*toLight,0) );
    float3 V  = SpotPos.xyz - worldPos;  
    float3 Vn  = normalize(V); 
    float3 lightvector = Vn;
    float3 lightdir = normalize(float3(angle.x,angle.y*2.0,angle.z));
    intensity = clamp(intensity * (dot(-lightdir,worldNormal)),0.0,1.0);
    return (SpotColor.xyz * pow(max(dot(-lightvector, lightdir ),0),conewidth) * 2.5 ) * intensity * diffusemap;
}


float3 CalcExtLightingVS(float3 Nb, float3 worldPos, float3 Vn )
{
	float3 output = float3(0,0,0);
    float3 toLight;
    float lightDist;
    float fAtten;
    float3 lightDir;
    float3 halfvec;
    float4 lit0;
	float4 local_lights_atten;
	
	//dl_pos[i].w = range.

	for( int i=dl_lights ; i < dl_lightsVS+dl_lights ; i++ )
	{

		if( dl_diffuse[i].w == 3.0 ) {
			output += CalcExtSpot(Nb,worldPos,dl_pos[i].xyz,dl_diffuse[i].xyz,dl_pos[i].w,dl_angle[i].xyz, float3(0.75,0.75,0.75));
		} else {
			toLight = dl_pos[i].xyz - worldPos;
			lightDist = length( toLight ) * 2.0;
			local_lights_atten = float4(1.0, 1.0/dl_pos[i].w, 1.0/(dl_pos[i].w*dl_pos[i].w), 0.0);
			fAtten = 1.0/dot( local_lights_atten, float4(1,lightDist,lightDist*lightDist,0) );
			lightDir = normalize( toLight );
			halfvec = normalize(Vn + lightDir);
			lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 
			lit0.z = clamp( ( lit0.z * TotalSpecular) ,0.0,1.0);
			output+= (lit0.y *dl_diffuse[i].xyz * fAtten ); //PE: no spec + (lit0.z * dl_diffuse[i].xyz * fAtten );   
		}

	}
	return output;
}


VSOutput VSMain(appdata input, uniform int geometrymode)
{
   VSOutput output;
   
   float3 inputPosition = float3(0,0,0);
   float3 inputNormal = float3(0,0,0);
   #ifdef PBRVEGETATION
    inputPosition = input.position;
    inputNormal = input.normal;
   #else
    #ifdef PBRTERRAIN
     inputPosition = input.position;
     inputNormal = input.normal;
    #else
     float3 inputBinormal = float3(0,0,0);
     float3 inputTangent = float3(0,0,0);
     #ifdef WITHANIMATION
	  if ( geometrymode == 1 )
	  {
	   // vertex animation
       for (int i = 0; i < 4; i++)
       {
        float index = input.Blendindices[i];
        float3x4 model = float3x4(boneMatrix[index][0], boneMatrix[index][1], boneMatrix[index][2]);     
        float3 vec3 = mul(model, float4(input.position, 1));
        vec3 = vec3 + boneMatrix[index][3].xyz;
        inputPosition += vec3.xyz * input.Blendweight[i];
        float3 norm3 = mul(model, float4(input.normal, 0));
        inputNormal += norm3.xyz * input.Blendweight[i];
        float3 tang3 = mul(model, float4(input.tangent, 0));
        inputTangent += tang3.xyz * input.Blendweight[i];
        float3 bino3 = mul(model, float4(input.binormal, 0));
        inputBinormal += bino3.xyz * input.Blendweight[i];
       }
	   #ifdef WITHANIMATION8BONE
	   // extra for models with 8 bones per vertex (MakeHuman/iClone)
       for (int ii = 0; ii < 4; ii++)
       {
        float index = input.BlendindicesExtra[ii];
        float3x4 model = float3x4(boneMatrix[index][0], boneMatrix[index][1], boneMatrix[index][2]);     
        float3 vec3 = mul(model, float4(input.position, 1));
        vec3 = vec3 + boneMatrix[index][3].xyz;
        inputPosition += vec3.xyz * input.BlendweightExtra[ii];
        float3 norm3 = mul(model, float4(input.normal, 0));
        inputNormal += norm3.xyz * input.BlendweightExtra[ii];
        float3 tang3 = mul(model, float4(input.tangent, 0));
        inputTangent += tang3.xyz * input.BlendweightExtra[ii];
        float3 bino3 = mul(model, float4(input.binormal, 0));
        inputBinormal += bino3.xyz * input.BlendweightExtra[ii];
       }  
	   #endif
	  }
	  else
	  {
	   // no vertex anim (for DepthMapNoAnim and Distant)
       inputPosition = input.position;
       inputNormal = input.normal.xyz;
       inputTangent = input.tangent.xyz;
       inputBinormal = input.binormal.xyz;
	  }
     #else
      inputPosition = input.position;
      inputNormal = input.normal.xyz;
      inputTangent = input.tangent.xyz;
      inputBinormal = input.binormal.xyz;
     #endif
    #endif
   #endif
   
   float3x3 wsTransform = (float3x3)World;
   #ifdef PBRVEGETATION
      // Grass clumps are hidden by setting the verts to a 200+ Y position offset in the grass area model
      if (inputPosition.y < 199)
      {   
        // animate the verts - model must have pivot at base of model on export
        float amplitude = pow( abs(SwayAmount * (1-input.uv.y) * 50.0f),1);
        float4 wave = amplitude * float4(sin(time*SwaySpeed+inputPosition.x),0,cos(time*SwaySpeed+inputPosition.z),0);
        inputPosition = inputPosition + wave.xyz;
     }
     else
     {
       inputPosition = float3(0,0,0);
     }   
   #endif
   output.position = mul(float4(inputPosition,1), World);

#ifdef PBRTERRAIN
   output.positionCS = mul(output.position, mul(View, Projection)); // 
#else
	//PE: depth buffer is based on this calculation so we need to use the same.
	//PE: otherwise we get floating point precision errors and z-fighting.
   output.positionCS = mul(float4(inputPosition,1), WorldViewProjection);
#endif

   output.normal = mul(inputNormal, wsTransform);   
   output.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
   output.viewDepth = mul(output.position, View).z;

   output.cameraPosition = eyePos.xyz; //PE: fixed now, used for faster render.

   #ifdef PBRVEGETATION
    output.uv = input.uv;
    // fade alpha with distance from camera
    float3 diff = output.position.xyz - eyePos.xyz;
    float fDist = sqrt(diff.x*diff.x+diff.z*diff.z);
    float fEdgePerc = max(0,fDist-(GrassFadeDistance*0.4f)) / (GrassFadeDistance*0.6f);
    output.color.a = 1.0f - fEdgePerc;
   #else
     #ifdef PBRTERRAIN
      output.uv = input.uv * 500.0f; 
      float3 c1 = cross(output.normal, float3(0.0, 0.0, 1.0)); 
      float3 c2 = cross(output.normal, float3(0.0, 1.0, 0.0)); 
      if (length(c1) > length(c2)) {
       output.tangent = c1;   
      } else {
       output.tangent = c2;   
      }
      output.tangent = normalize(output.tangent);
      output.binormal = normalize(cross(output.normal, output.tangent)); 
    #else
     output.uv = float2(ScrollScaleUV.x+(input.uv.x*ScrollScaleUV.z),ScrollScaleUV.y+(input.uv.y*ScrollScaleUV.w));
     
     // PE: tangent has problems, calculate.
     //if ( abs(inputNormal.y) > 0.999 ) inputTangent = float3( inputNormal.y,0.0,0.0 );
     //else inputTangent = normalize( float3(-inputNormal.z, 0.0, inputNormal.x) );
     //inputBinormal = normalize( float3(inputNormal.y*inputTangent.z, inputNormal.z*inputTangent.x-inputNormal.x*inputTangent.z, //-inputNormal.y*inputTangent.x) );
	 
	 // LEE: Fixed above tangent/binormal calculation (see Concrete Girder)
#ifndef USEPARALLAXMAPPING
	 if ( ArtFlagControl1.y == 0 )
	 {
		 float3 c1 = cross(output.normal, float3(0.0, 0.0, 1.0)); 
		 float3 c2 = cross(output.normal, float3(0.0, 1.0, 0.0)); 
		 if (length(c1) > length(c2)) {
		  output.tangent = c1;   
		 } else {
		  output.tangent = c2;   
		 }
		 inputTangent = normalize(output.tangent);
		 inputBinormal = normalize(cross(inputTangent, output.normal)); 
     }
#endif
     output.tangent = mul(inputTangent, wsTransform);
     output.binormal = mul(inputBinormal, wsTransform);
	 
    #endif
    output.binormal = normalize(output.binormal);
    output.tangent = normalize(output.tangent);
   #endif
   output.normal = normalize(output.normal);
   output.clip = dot(output.position, clipPlane);                                                                      

	float3 trueCameraPosition = float3(ViewInv._m30,ViewInv._m31,ViewInv._m32);
	float3 eyeraw = trueCameraPosition - output.position.xyz;

	//	output.cameraPosition = trueCameraPosition; //PE:

	output.VertexLight.xyz = CalcExtLightingVS(output.normal.xyz, output.position.xyz, eyeraw.xyz );

	//PE: Experimental , http://www.mvps.org/directx/articles/linear_z/linearz.htm
	//PE: z fighting. We need to extract the far plane somehow to test it.
	//output.positionCS.z = output.positionCS.z * output.positionCS.w / 5000.0f;

#ifdef PBRTERRAIN
//PE: Something is wrong with the terrin normals, they are often set is flat output.normal.y > 0.9985 , but are not flat ?
//PE: So need to disable this for now.
//    if(output.positionCS.z > 3400.0 && output.position.y < 460.0 && output.normal.y > 0.9985 ) {
//      output.clip=-1.0;
//      output.positionCS.z = 100000.0;
//      output.positionCS.x = 100000.0;
//      output.positionCS.y = 100000.0;
//      output.positionCS.w = 0.0;
//    }
#endif
   #ifdef LIGHTMAPPED
    output.uv2 = input.uv2;
   #endif

   return output;
}

struct Light
{
   float4 color;
   float3 position;
   float3 lightVector;
   float intensity;
};

struct Attributes
{
   float3 position;
   float2 uv;
   float3 normal;
   #ifndef PBRVEGETATION
    float3 binormal;
    float3 tangent;
   #endif
};

#ifdef PBRVEGETATION
 Texture2D AlbedoMap : register( t0 );
 Texture2D Unused1Map : register( t1 );
 Texture2D Unused2Map : register( t2 );
 Texture2D Unused3Map : register( t3 );
 Texture2D Unused4Map : register( t4 );
 Texture2D Unused5Map : register( t5 );
 Texture2D Unused6Map : register( t7 );
#else
 #ifdef PBRTERRAIN
  Texture2D VegShadowSampler : register( t0 );
  Texture2D AGEDMap : register( t1 );
  Texture2D AlbedoMap : register( t2 );
  Texture2D HighlighterSampler : register( t3 );
  Texture2D NormalMap : register( t4 );
  Texture2D MetalnessMap : register( t5 );
  Texture2D Unused1Map : register( t7 );
 #else
  Texture2D AlbedoMap : register( t0 );
  #ifdef AOISAGED
   Texture2D AGEDMap : register( t1 );
   Texture2D NormalMap : register( t2 );
   Texture2D MetalnessMap : register( t3 );
   Texture2D Unused1Map : register( t4 );
   Texture2D Unused2Map : register( t5 );
   Texture2D Unused3Map : register( t7 );
  #else
   Texture2D AOMap : register( t1 );
   Texture2D NormalMap : register( t2 );
   Texture2D MetalnessMap : register( t3 );
   Texture2D GlossMap : register( t4 );
   Texture2D HeightMap : register( t5 );
   #ifdef ILLUMINATIONMAP
    Texture2D IlluminationMap : register( t7 );
   #else
    Texture2D DetailMap : register( t7 );
   #endif
  #endif
 #endif
#endif
TextureCube EnvironmentMap : register( t6 );
//PE: changed register t7 to t8 so we can just skip it. ( old t8 changed to t7 )
//Texture2D GlossCurveMap : register( t8 ); //PE: not really needed. i already do it in code below.

#ifdef WITHCHARACTERCREATORMASK
 Texture2D MaskMap : register( t11 );
#endif

SamplerState AnisoClamp
{
   Filter = ANISOTROPIC;
   AddressU = Clamp;
   AddressV = Clamp;
};
SamplerState SampleWrap
{
#ifdef TRILINEAR
    Filter = MIN_MAG_MIP_LINEAR;
#else
	Filter = ANISOTROPIC;
    MaxAnisotropy = MAXANISOTROPY;
#endif
    AddressU = Wrap;
    AddressV = Wrap;
};
SamplerState SampleWrapLimitLOD
{
#ifdef TRILINEAR
    Filter = MIN_MAG_MIP_LINEAR;
#else
	Filter = ANISOTROPIC;
    MaxAnisotropy = MAXANISOTROPY;
#endif
    AddressU = Wrap;
    AddressV = Wrap;
	MAXLOD = 6; // prevent "brown" lines in the distance.
};
SamplerState SampleAniso
{
#ifdef TRILINEAR
    Filter = MIN_MAG_MIP_LINEAR;
#else
    Filter = ANISOTROPIC;
    MaxAnisotropy = MAXANISOTROPYTERRAIN;
#endif
    AddressU = Wrap;
    AddressV = Wrap;
    MAXLOD = 6; // prevent "brown" lines in the distance.
};
SamplerState SampleClamp
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

#ifndef PBRVEGETATION
#ifndef PBRTERRAIN
#ifdef USEPARALLAXMAPPING

float parallaxSoftShadowMultiplier(in float3 L, in float2 initialTexCoord, in float initialHeight, in float parallaxOcclusionMapping)
{
	float shadowMultiplier = 1; //no shadow

	const float minLayers = 15;
	const float maxLayers = 30;

	if (dot(float3(0, 0, 1), L) > 0)
	{
		float numSamplesUnderSurface = 0;
		shadowMultiplier = 0;
		float numLayers = lerp(maxLayers, minLayers, abs(dot(float3(0, 0, 1), L)));
		float layerHeight = initialHeight / numLayers;
		float2 texStep = parallaxOcclusionMapping * L.xy / L.z / numLayers;

		float currentLayerHeight = initialHeight - layerHeight;
		float2 currentTextureCoords = initialTexCoord + texStep;
		float heightFromTexture = HeightMap.SampleLevel(SampleWrap, currentTextureCoords, 0).r;
		int stepIndex = 1;

		// while point is below depth 0.0 )
		while (currentLayerHeight > 0 && stepIndex <= maxLayers)
		{
			if (heightFromTexture < currentLayerHeight)
			{
				numSamplesUnderSurface += 1;
				float newShadowMultiplier = (currentLayerHeight - heightFromTexture) * (1.0 - stepIndex / numLayers);
				newShadowMultiplier *= 4;
				shadowMultiplier = max(shadowMultiplier, newShadowMultiplier);
			}

			stepIndex += 1;
			currentLayerHeight -= layerHeight;
			currentTextureCoords += texStep;
			heightFromTexture = HeightMap.SampleLevel(SampleWrap, currentTextureCoords, 0).r;
		}

		if (numSamplesUnderSurface < 1)
		{
			shadowMultiplier = 1;
		}
		else
		{
			shadowMultiplier = 1.0 - shadowMultiplier;
		}
	}
	return shadowMultiplier;
}

float2 ParallaxOcclusionMapping_Calc
(
	in float3 V,
	in float3x3 TBN,
	in float parallaxOcclusionMapping,
	in float2 uv,
	out float parallaxHeight
)
{

	parallaxHeight = 0;
	//int minLayers = 8;
	//int maxLayers = 50;//32;
	uint numSteps = 50; //abs( lerp(maxLayers, minLayers, abs(dot(float3(0.0, 0.0, 1.0), V))) );
	//uint numSteps = abs( lerp(maxLayers, minLayers, dot( normalize(V), attributes.normal.xyz ) ) );

	[branch]
	if (parallaxOcclusionMapping > 0) //0 to 0.1
	{
		float2 uv_dx = ddx_coarse(uv);
		float2 uv_dy = ddy_coarse(uv);

		V = mul(TBN, V);
		V.xy /= V.z;

		float layerHeight = 1.0 / numSteps;
		float curLayerHeight = 0;
		float2 dtex = parallaxOcclusionMapping * V.xy / numSteps;

		float2 currentTextureCoords = uv;
		float heightFromTexture = 1 - HeightMap.SampleGrad(SampleWrap, currentTextureCoords, uv_dx, uv_dy).r;

		uint iter = 0;
		[loop]
		while (heightFromTexture > curLayerHeight && iter < numSteps)
		{
			curLayerHeight += layerHeight;
			currentTextureCoords -= dtex;
			heightFromTexture = 1 - HeightMap.SampleGrad(SampleWrap, currentTextureCoords, uv_dx, uv_dy).r;
			iter++;
		}
		float2 prevTCoords = currentTextureCoords + dtex;
		float nextH = heightFromTexture - curLayerHeight;

		float prevH = 1 - HeightMap.SampleGrad(SampleWrap, prevTCoords, uv_dx, uv_dy).r - curLayerHeight + layerHeight;
		float weight = nextH / (nextH - prevH);
		float2 finalTextureCoords = mad(prevTCoords, weight, currentTextureCoords * (1.0 - weight));
		float2 difference = finalTextureCoords - uv;
		uv += difference.xy;

		// interpolation of depth values //for soft shadows
		parallaxHeight = curLayerHeight + prevH * weight + nextH * (1.0 - weight);
	}

	return uv;

}

#endif
#endif
#endif

#ifdef PBRTERRAIN
float Atlas16GetUV ( in float textargetselectorV, in float texselectorV, in float2 TexCoord, out float2 texatlasuv, out int texcol, out int texrow )
{
   // select tex from 16atlas
   float factor = 0.0f;
   uint texindex = textargetselectorV * 16.0f;
   float deductV = texselectorV - (texindex*0.0625f);
   factor = max(0,0.0625f-abs(deductV))*16.0f;
   texrow = texindex / 4;
   texcol = texindex - (texrow*4);

   texatlasuv = TexCoord/4.0f;
   int udiv = texatlasuv.x / 0.25f;
   int vdiv = texatlasuv.y / 0.25f;
   texatlasuv.x = texatlasuv.x - (udiv*0.25f);
   texatlasuv.y = texatlasuv.y - (vdiv*0.25f);   

   // crop outer pixel edges for seamless mipmaps
   texatlasuv = texatlasuv / 1024.0f;
   texatlasuv = texatlasuv * 512.0f;
   texatlasuv = texatlasuv + ((0.25f/1024.0f)*256.0f);

   return factor;
}
void Atlas16DiffuseLookupCenter( in float4 VegShadowColor, in float2 TexCoord, in out float4 diffusemap )
{
   // vars
   int texcol = 0;
   int texrow = 0;
   float2 texatlasuv = float2(0,0);
   //float fround = float( round(VegShadowColor.b * 16.0) / 16 ); // hard edge.
   float fround = VegShadowColor.b;
   
   float texselectorV = min(fround,0.9375f);
   float2 texDdx = ddx(TexCoord*0.125f);
   float2 texDdy = ddy(TexCoord*0.125f);

   // center sample
   float texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord,texatlasuv,texcol,texrow);
   float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
   diffusemap += AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * texcenterfactor;    
}
void Atlas16DiffuseLookupCenterDist( in float4 VegShadowColor, in float2 TexCoord, in out float4 diffusemap, in float vDepth )
{
   // vars
   int texcol = 0;
   int texrow = 0;
   float2 texatlasuv = float2(0,0);
   float fround = VegShadowColor.b;
   
   float texselectorV = min(fround,0.9375f);
   float2 texDdx = ddx(TexCoord*0.125f);
   float2 texDdy = ddy(TexCoord*0.125f);

   float texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord,texatlasuv,texcol,texrow);
   float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
   float4 diffusemapA = AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * texcenterfactor;          

   texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord/5.0,texatlasuv,texcol,texrow);
   finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
   float4 diffusemapB = AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * texcenterfactor;          

   diffusemap += lerp( diffusemapA, diffusemapB, clamp(vDepth/1200.0,0.00,0.50) );    
}
void Atlas16DiffuseNormalLookupCenter( in float4 VegShadowColor, in float2 TexCoord, in out float4 diffusemap, in out float3 normalmap , in float vDepth)
{
   // vars
   int texcol = 0;
   int texrow = 0;
   float2 texatlasuv = float2(0,0);
   float texselectorV = min(VegShadowColor.b,0.9375f);
   float2 texDdx = ddx(TexCoord*0.125f);
   float2 texDdy = ddy(TexCoord*0.125f);

#ifdef IMPROVEDISTANCE
    float texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord,texatlasuv,texcol,texrow);
    float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    float4 diffusemapA = AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * texcenterfactor;
    normalmap += NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb * texcenterfactor;
    texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord/5.0,texatlasuv,texcol,texrow);
    finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    float4 diffusemapB = AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * texcenterfactor;
    diffusemap += lerp( diffusemapA, diffusemapB, clamp(vDepth/1200.0,0.00,0.50) );    
#else
   // center sample
   float texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord,texatlasuv,texcol,texrow);
   float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
   diffusemap += AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * texcenterfactor;
   normalmap += NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb * texcenterfactor;
#endif
}
void Atlas16DiffuseNormalLookup( in float4 VegShadowColor, in float2 TexCoord, in out float4 diffusemap, in out float3 normalmap , in float vDepth)
{
   // vars
   int texcol = 0;
   int texrow = 0;
   float2 texatlasuv = float2(0,0);
   float texselectorV = min(VegShadowColor.b,0.9375f);
   float2 texDdx = ddx(TexCoord*0.125f);
   float2 texDdy = ddy(TexCoord*0.125f);
   


   // secondary sample
   float secondarylayer = VegShadowColor.g;
   if ( secondarylayer > 0 )
   {
    float texsecondaryfactor = Atlas16GetUV(0,0,TexCoord,texatlasuv,texcol,texrow);
    float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    diffusemap = lerp(diffusemap,AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy),secondarylayer);
    normalmap = lerp(normalmap,NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb,secondarylayer);
   }
   float invsecondarylayer = 1.0f - secondarylayer;
   //Assume grass , saves alot of processing.
   if(VegShadowColor.b >= 0.227 && VegShadowColor.b <= 0.283 ) {
      return;
   }   
   // center sample
#ifdef IMPROVEDISTANCE
    float texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord,texatlasuv,texcol,texrow);
    float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    float4 diffusemapA = lerp( diffusemap , AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) , ( texcenterfactor * invsecondarylayer) );
    normalmap = lerp(normalmap, NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb , (texcenterfactor* invsecondarylayer ) );
    texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord/5.0,texatlasuv,texcol,texrow);
    finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    float4 diffusemapB = lerp( diffusemap , AlbedoMap.SampleGrad(SampleAniso,finaluv, texDdx, texDdy) , (texcenterfactor * invsecondarylayer) );
    diffusemap = lerp( diffusemapA, diffusemapB, clamp(vDepth/1200.0,0.00,0.50) );
#else
   float texcenterfactor = Atlas16GetUV(texselectorV,texselectorV,TexCoord,texatlasuv,texcol,texrow);
   float2 finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
   diffusemap += AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * (texcenterfactor * invsecondarylayer);
   normalmap += NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb * (texcenterfactor * invsecondarylayer);
#endif
   // higher sample
#ifdef IMPROVEDISTANCE
    float texhigherfactor = Atlas16GetUV((texselectorV+0.0625f),texselectorV,TexCoord,texatlasuv,texcol,texrow);
    finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    diffusemapA = lerp( diffusemap , AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) , (texhigherfactor * invsecondarylayer) );
    normalmap = lerp(normalmap , NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb , (texhigherfactor * invsecondarylayer) );
    texhigherfactor = Atlas16GetUV((texselectorV+0.0625f),texselectorV,TexCoord/5.0,texatlasuv,texcol,texrow);
    finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    diffusemapB = lerp( diffusemap , AlbedoMap.SampleGrad(SampleAniso,finaluv, texDdx, texDdy) , (texhigherfactor * invsecondarylayer) );
    diffusemap = lerp( diffusemapA, diffusemapB, clamp(vDepth/1200.0,0.00,0.50) );
#else
   float texhigherfactor = Atlas16GetUV((texselectorV+0.0625f),texselectorV,TexCoord,texatlasuv,texcol,texrow);
   finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
   diffusemap += AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * (texhigherfactor * invsecondarylayer);
   normalmap += NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb * (texhigherfactor * invsecondarylayer);
#endif

#ifdef NEVER_ACTIVE
	//PE: This has never been active, texlowerfactor is always 0.
	// lower sample
   if ( texselectorV >= 0.0625f )
   {
#ifdef IMPROVEDISTANCE
     float texlowerfactor = Atlas16GetUV((texselectorV-0.0625f),texselectorV,TexCoord,texatlasuv,texcol,texrow);
     finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
     diffusemapA = lerp( diffusemap , AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) , (texlowerfactor * invsecondarylayer) );
     normalmap = lerp( normalmap , NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb , (texlowerfactor * invsecondarylayer) );
     texlowerfactor = Atlas16GetUV((texselectorV-0.0625f),texselectorV,TexCoord/5.0,texatlasuv,texcol,texrow);
     finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
     diffusemapB = lerp( diffusemap , AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) , (texlowerfactor * invsecondarylayer) );   
     diffusemap = lerp( diffusemapA, diffusemapB, clamp(vDepth/1200.0,0.00,0.50) );
#else
    float texlowerfactor = Atlas16GetUV((texselectorV-0.0625f),texselectorV,TexCoord,texatlasuv,texcol,texrow);
    finaluv = float2(texatlasuv+float2(texcol*0.25f,texrow*0.25f));
    diffusemap += AlbedoMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy) * (texlowerfactor * invsecondarylayer);
    normalmap += NormalMap.SampleGrad(SampleAniso,finaluv,texDdx,texDdy).rgb * (texlowerfactor * invsecondarylayer);
#endif
   }   
#endif
}
#endif
         
struct DirectionalLight
{
   float4 Ambient;
   float4 Diffuse;
   float4 Specular;
   float3 Direction;
   float pad;
};
struct PointLight
{
   float4 Ambient;
   float4 Diffuse;
   float4 Specular;
   float3 Position;
   float Range;
   float3 Att;
   float pad;
};
struct SpotLight
{
   float4 Ambient;
   float4 Diffuse;
   float4 Specular;
   float3 Position;
   float Range;
   float3 Direction;
   float Spot;
   float3 Att;
   float pad;
};
struct Material
{
   float4 Ambient;
   float4 Diffuse;
   float4 Specular;
   float4 Properties; //r = reflectance, g = metallic, b = roughness
};
float CelShadingFunc(float factor)
{
   float newFactor = 0.0f;

   if (factor <= 0.0f)
   {
      newFactor = 0.1;
   }
   else if (factor > 0.0f && factor <= 0.2f)
   {
      newFactor = 0.4;
   }
   else if (factor > 0.2f && factor <= 1.0f)
   {
      newFactor = 1.0f;
   }

   return newFactor;
}
float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 11.2;
float3 Uncharted2Tonemap(float3 x)
{
   return ((x*(A*x + C*B) + D*E) / (x*(A*x + B) + D*F)) - E / F;
}
typedef uint U32;
float chiGGX(float v)
{
   return v > 0 ? 1 : 0;
}
float D_GGX(float roughness, float NoH)
{
   float a = roughness * roughness;
   float a2 = a * a;
   float NoH2 = NoH * NoH;
   float denom = max(NoH2 * (a2 - 1.0f) + 1.0f , 0.00390625); //PE: Added this to remove white dots caused by division by zero (float roundings).
   return a2 / (PI * denom * denom);
}
float G_Smith_Schlick(float roughness, float NoV, float NoL)
{
   float a = roughness * roughness;
   float k;
#if K_MODEL_SCHLICK
   k = a * 0.5f;
#elif K_MODEL_CRYTEK
   k = (0.8f + 0.5f * a);
   k = k * k;
   k = 0.5f * k;
#elif K_MODEL_DISNEY
   k = a + 1;
   k = k * k;
   k = k * 0.125f;
#endif
   float GV = NoV / (NoV * (1 - k) + k);
   float GL = NoL / (NoL * (1 - k) + k);
   return GV * GL;
}
float G_Smith_GGX(float roughness, float NoV, float NoL)
{
   float a = roughness * roughness;
   float GV = NoL * (NoV * (1 - a) + a);
   float GL = NoV * (NoL * (1 - a) + a);
   return 0.5 * rcp(GV + GL);
}
float3 F_Schlick(float3 SpecularColor, float VoH)
{
   float Fc = pow((1 - VoH), 5);
   return saturate(50.0f * SpecularColor.g) * Fc + (1 - Fc) * SpecularColor;
}
float3 RefAtNormalIncidence(float3 albedo, float metallic, float reflectivity)
{
   float ior = 1 + reflectivity;
   float3 F0 = abs((1.0 - ior) / (1.0 + ior));
   F0 = F0 * F0;
   F0 = lerp(F0, albedo, metallic);
   return F0;
}
float3 F_Schlick_Gau_Ver(float VoH, float3 F0)
{
   //normal way
   //return F0 + (1 - F0) * pow((1 - VoH), 5);
   //Spherical Gaussian Approximation
   //Reference: Seb. Lagarde's Blog (seblagarde.wordpress.com)
   return F0 + (1 - F0) * exp2((-5.55473 * VoH - 6.98316) * VoH);
}
float3 F_Schlick_With_F0(float VoH, float3 albedo, float metallic, float reflectivity)
{
   float3 F0 = RefAtNormalIncidence(albedo, metallic, reflectivity);
   return F_Schlick_Gau_Ver(VoH, F0);
}
float3 F_Schlick_Roughness(float3 SpecularColor, float roughness, float3 VoH)
{
   float a = roughness * roughness;
   float alpharoughness = 1.0f - a;
   float3 fresnel = max(float3(alpharoughness,alpharoughness,alpharoughness), SpecularColor);
   fresnel -= SpecularColor;
   fresnel *= pow(float3(1,1,1) - VoH, 5);
   fresnel += SpecularColor;
   return fresnel;
}

float3 CookTorranceSpecFactor(float3 normal, float3 viewer, float metallic, float roughness, float3 lightDir, float3 albedo)
{
#if K_MODEL_PE
   roughness = max(0.05f,roughness);
   float3 light = -lightDir;
   float3 halfVector = normalize(light + viewer);
   float NoL = saturate(dot(normal, light));
   float NoH = saturate(dot(normal, halfVector));
   float NoV = saturate(dot(normal, viewer));
   float3 realSpec = lerp(0.03f, albedo, metallic);
   float3 fresnel = F_Schlick(realSpec, NoV);
   //PE: cartoniss cut gone.
   //PE: When we get SunColor - look at albedo used as spec color, sun should be part.
   float geometry = G_Smith_Schlick(roughness, NoV, NoL);
   float distribution = D_GGX(roughness, NoH); // PE: produce artifacts , white highlight around roughness changes. AntiAlising in pic ?
   float3 numerator = (fresnel * geometry * distribution);
   return numerator * 0.5; //PE: just use a fixed so we dont get sudden changes *0.5 looks fine.
#else
   roughness = max(0.05f,roughness);
   float3 light = -lightDir;
   float3 halfVector = normalize(light + viewer);
   float NoL = saturate(dot(normal, light));
   float NoH = saturate(dot(normal, halfVector));
   float NoV = saturate(dot(normal, viewer));
   float VoH = saturate(dot(viewer, halfVector));
   float LoH = saturate(dot(light, halfVector));
   float3 realSpec = lerp(0.03f, albedo, metallic);
   float3 fresnel;
   fresnel = F_Schlick(realSpec, NoV);
   float geometry;
   geometry = G_Smith_Schlick(roughness, NoV, NoL);
   float distribution;
   distribution = D_GGX(roughness, NoH);
   float3 numerator = (fresnel * geometry * distribution);
   float denominator = 4.0f * (NoV * NoL) + 0.0001; //prevent light aliasing on metals
   float3 RS = numerator / denominator;
   return RS;
#endif
}
float3 ComputeLight(Material mat, DirectionalLight L, float3 normal, float3 toEye, float3 albedo)
{
// also produce highlights (mat.Properties.b).

#if K_MODEL_PE
    #ifdef LIGHTMAPPED
     float3 thisSunColor = mSunColor * SurfaceSunFactor;
    #else
    // float3 thisSunColor = mSunColor;
     float3 thisSunColor = mSunColor;
	#endif
	#ifdef PBRVEGETATION
	 float3 vegFinalSun = clamp(dot(-L.Direction, normal) * thisSunColor, 0.10, 1.0);
	 vegFinalSun = lerp(0.65, vegFinalSun, SurfaceSunFactor); //PE: SurfaceSunFactor even out directional light on vegetation.

#ifdef COMPRESSLIGHTRANGE
	 vegFinalSun = (float3(1.0, 1.0, 1.0) - exp(-(vegFinalSun + 0.10))); //move lightrange from darkside , display more detail in dark areas.
#endif

	 return  vegFinalSun * ((albedo)*0.85);
	#endif
	float3 albedoAdd = lerp( max(albedo.rgb, dot(-L.Direction,normal)*0.15) , albedo.rgb , RealisticVsCool ); // Give light side a bit more spec.
	float3 specular = CookTorranceSpecFactor(normal, toEye, mat.Properties.g, mat.Properties.b, L.Direction, albedoAdd);
	specular = (specular * TotalSpecular) * SurfaceSunFactor; //PE: SurfaceSunFactor also remove specular from sun only.
    #ifdef LIGHTMAPPED
     float3 thisNonSunColor = mSunColor * (1-SurfaceSunFactor);
     float3 thisFinalSunColor = clamp(dot(-L.Direction,normal) * thisSunColor,0.10,1.0) + thisNonSunColor;
    #else
     float3 thisFinalSunColor = clamp(dot(-L.Direction,normal) * thisSunColor,0.10,1.0);
	 thisFinalSunColor = lerp(0.65, thisFinalSunColor, SurfaceSunFactor); //PE: SurfaceSunFactor is used to even out directional light :)
	#endif

#ifdef COMPRESSLIGHTRANGE
	thisFinalSunColor = (float3(1.0,1.0,1.0) - exp(-(thisFinalSunColor+0.10) )); //move lightrange from darkside , display more detail in dark areas.
	specular = (float3(1.0, 1.0, 1.0) - exp(-(specular) * 0.75 )); //move lightrange from lightside to darkside.
#endif

	return thisFinalSunColor * ((albedoAdd * (1.0-specular))*0.85) + (specular*thisSunColor);
#else
   float3 resultLight = float3(0.0f, 0.0f, 0.0f);
   float NdotL = saturate(dot(normal, -L.Direction));
   #ifdef PBRVEGETATION
   float3 specular = float3(0,0,0);
   #else
   float3 specular = CookTorranceSpecFactor(normal, toEye, mat.Properties.g, mat.Properties.b, L.Direction, albedo);
   #endif
   resultLight = L.Diffuse.rgb * NdotL * (albedo * (float3(1,1,1) - specular));
   resultLight += L.Diffuse.rgb * specular;
   return resultLight;
#endif
}
void ComputeDirectionalLight(Material mat, DirectionalLight L,
   float3 normal, float3 toEye,
   out float4 ambient,
   out float4 diffuse,
   out float4 spec)
{
   // Initialize outputs.
   ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
   diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
   spec = float4(0.0f, 0.0f, 0.0f, 0.0f);

   // The light vector aims opposite the direction the light rays travel.
   float3 lightVec = -L.Direction;

   // Add ambient term.
   ambient = mat.Ambient * L.Ambient;

   // Add diffuse and specular term, provided the surface is in 
   // the line of site of the light.

   float diffuseFactor = dot(lightVec, normal);

   [flatten]
   if (diffuseFactor > 0.0f)
   {
      float specFactor;
      
      float3 h = normalize(lightVec + toEye);
      float NdotH = max(0.0f, dot(normal, h));
      specFactor = pow(NdotH, mat.Specular.w);
      
      diffuse = diffuseFactor * mat.Diffuse * L.Diffuse;
      spec = specFactor * mat.Specular * L.Specular;
   }
   
}
void ComputePointLight(Material mat, PointLight L, float3 pos, float3 normal, float3 toEye,
   out float4 ambient, out float4 diffuse, out float4 spec)
{
   // Initialize outputs.
   ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
   diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
   spec = float4(0.0f, 0.0f, 0.0f, 0.0f);

   // The vector from the surface to the light.
   float3 lightVec = L.Position - pos;

   // The distance from surface to light.
   float d = length(lightVec);

   // Range test.
   if (d > L.Range)
      return;

   // Normalize the light vector.
   lightVec /= d;

   // Ambient term.
   ambient = mat.Ambient * L.Ambient;

   // Add diffuse and specular term, provided the surface is in 
   // the line of site of the light.
   float diffuseFactor = dot(lightVec, normal);

   // Flatten to avoid dynamic branching.
   [flatten]
   if (diffuseFactor > 0.0f)
   {
      float3 v = reflect(-lightVec, normal);
      float specFactor = pow(max(dot(v, toEye), 0.0f), mat.Specular.w);

      diffuse = diffuseFactor * mat.Diffuse * L.Diffuse;
      spec = specFactor * mat.Specular * L.Specular;
   }

   // Attenuate
   float att = clamp(1.0f - d*d / (L.Range*L.Range), 0.0f, 1.0f);

   diffuse *= att;
   spec *= att;
}
void ComputeSpotLight(Material mat, SpotLight L, float3 pos, float3 normal, float3 toEye,
   out float4 ambient, out float4 diffuse, out float4 spec)
{
   // Initialize outputs.
   ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
   diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
   spec = float4(0.0f, 0.0f, 0.0f, 0.0f);

   // The vector from the surface to the light.
   float3 lightVec = L.Position - pos;

   // The distance from surface to light.
   float d = length(lightVec);

   // Range test.
   if (d > L.Range)
      return;

   // Normalize the light vector.
   lightVec /= d;

   // Ambient term.
   ambient = mat.Ambient * L.Ambient;

   // Add diffuse and specular term, provided the surface is in 
   // the line of site of the light.

   float diffuseFactor = dot(lightVec, normal);

   // Flatten to avoid dynamic branching.
   [flatten]
   if (diffuseFactor > 0.0f)
   {
      float3 v = reflect(-lightVec, normal);
      float specFactor = pow(max(dot(v, toEye), 0.0f), mat.Specular.w);

      diffuse = diffuseFactor * mat.Diffuse * L.Diffuse;
      spec = specFactor * mat.Specular * L.Specular;
   }

   // Scale by spotlight factor and attenuate.
   float spot = pow(max(dot(-lightVec, L.Direction), 0.0f), L.Spot);

   // Scale by spotlight factor and attenuate.
   float att = spot / dot(L.Att, float3(1.0f, d, d*d));

   ambient *= spot;
   diffuse *= att;
   spec *= att;
}
float3 CalcSpotFlash( float3 worldNormal, float3 worldPos )
{
	// muzzle flash, explosion, etc
    float3 output = (float3)0.0;
    float3 toLight = (SpotFlashPos.xyz - worldPos.xyz);
    float3 lightDir = normalize( toLight );
    float lightDist = length( toLight );
    float MinFalloff = 100; 
    float LinearFalloff = 1;
    float ExpFalloff = .005;
    float fSpotFlashPosW = clamp(0,1,SpotFlashPos.w);    
    float fAtten = 1.0/(MinFalloff + (LinearFalloff*lightDist)+(ExpFalloff*lightDist*lightDist));
    output += SpotFlashColor.xyz * fAtten * (fSpotFlashPosW) * max(0,dot(worldNormal,lightDir));
    return output;
}

/*
float CalcFlashLight( float3 worldPos)
{
    // flash light system (flash light control carried in SpotFlashColor.w )
	float4 viewspacePos = mul(float4(worldPos,1), View);
    float conewidth = 24;
    float intensity = max(0, 1.5f - (viewspacePos.z/500.0f));
    float3 V  = eyePos.xyz - worldPos;  
    float3 Vn  = normalize(V); 
    float3 lightvector = Vn;
    float3 lightdir = float3(View._m02,View._m12,View._m22);
    return pow(max(dot(-lightvector, lightdir),0),conewidth) * intensity * SpotFlashColor.w;   
}
*/

#ifdef WITHCHARACTERCREATORMASK
float4 CharacterCreatorDiffuse(float4 diffusemap,float2 uv)
{
	float amountfromMask[4];
	float amountfromPixel[4];
	float4 maskmap = MaskMap.Sample(SampleWrap,uv);
	amountfromMask[0] = maskmap.r * ToneMix[0];
	amountfromMask[1] = maskmap.g * ToneMix[1];
	amountfromMask[2] = maskmap.b * ToneMix[2];
	amountfromMask[3] = maskmap.a * ToneMix[3];
	for ( int c = 0 ; c < 4 ; c++ )
	{
	  if ( amountfromMask[c] > 0.0 && ColorTone[c].r >= 0.0f )
	  {
		 amountfromPixel[c] = 1.0f - amountfromMask[c];
		 diffusemap = (diffusemap * amountfromPixel[c]) + (ColorTone[c] * amountfromMask[c]);
	  }
	}
	return diffusemap;
}
#endif

float3 CalcExtLighting(float3 Nb, float3 worldPos, float3 Vn, float3 diffusemap, float3 specmap )
{
	float3 output = GlowIntensity.xyz;
#ifdef ENABLE_PULSE_HIGHLIGHTING
	output *= abs(sin(time*PULSE_HIGHLIGHTING_SPEED)); // abs(sintime);
#endif
	float3 toLight;
    float lightDist;
    float fAtten;
    float3 lightDir;
    float3 halfvec;
    float4 lit0;
	float4 local_lights_atten;
	
	//dl_pos[i].w = range.

	for( int i=0 ; i < dl_lights ; i++ ) {

		if( dl_diffuse[i].w == 3.0 ) {
			output += CalcExtSpot(Nb,worldPos,dl_pos[i].xyz,dl_diffuse[i].xyz,dl_pos[i].w,dl_angle[i].xyz,diffusemap);
		} else {

			toLight = dl_pos[i].xyz - worldPos;
			lightDist = length( toLight ) * 2.0;
			local_lights_atten = float4(1.0, 1.0/dl_pos[i].w, 1.0/(dl_pos[i].w*dl_pos[i].w), 0.0);
			fAtten = 1.0/dot( local_lights_atten, float4(1,lightDist,lightDist*lightDist,0) );
			lightDir = normalize( toLight );
			halfvec = normalize(Vn + lightDir);
			lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 
			lit0.z = clamp( ( lit0.z * TotalSpecular) ,0.0,1.0);
			output += (lit0.y *dl_diffuse[i].xyz * fAtten * 1.7*diffusemap) + (lit0.z * dl_diffuse[i].xyz * fAtten * 0.5 );   
		}
	}
	return output;
}

float3 CalcExtLightingPBR(float3 Nb, float3 worldPos, float3 Vn, float3 diffusemap, float3 specmap, float3 toEye, float metallic, float roughness )
{
	float3 output = GlowIntensity.xyz;
#ifdef ENABLE_PULSE_HIGHLIGHTING
	output *= abs(sin(time*PULSE_HIGHLIGHTING_SPEED)); // abs(sintime);
#endif
	float3 loutp;
    float3 toLight;
    float lightDist;
    float fAtten;
    float3 lightDir;
    float3 halfvec;
    float4 lit0;
	float3 albedoAdd = float3(1.0,1.0,1.0);
	float3 fspecular;
	float4 local_lights_atten;
	
	//dl_pos[i].w = range.

	for( int i=0 ; i < dl_lights ; i++ ) {

		if( dl_diffuse[i].w == 3.0 ) {
			output += CalcExtSpot(Nb,worldPos,dl_pos[i].xyz,dl_diffuse[i].xyz,dl_pos[i].w,dl_angle[i].xyz,diffusemap);
		} else {

			toLight = dl_pos[i].xyz - worldPos;
			lightDist = length( toLight )*2.0;
			local_lights_atten = float4(1.0, 1.0/dl_pos[i].w, 1.0/(dl_pos[i].w*dl_pos[i].w), 0.0);
			fAtten = 1.0/dot( local_lights_atten, float4(1,lightDist,lightDist*lightDist,0) );
			lightDir = normalize( toLight );
			halfvec = normalize(Vn + lightDir);
			lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 

			fspecular = CookTorranceSpecFactor(Nb, toEye, metallic, roughness, -lightDir, albedoAdd);
			fspecular = clamp( ( fspecular * TotalSpecular) ,0.0,1.0);

			output += (lit0.y *dl_diffuse[i].xyz * fAtten * 1.7*diffusemap) + (fspecular * dl_diffuse[i].xyz * fAtten  );   
		}

	}
	return output;
}


float3 CalcLightingPBR(float3 Nb, float3 worldPos, float3 Vn, float3 diffusemap, float3 specmap, float3 toEye, float metallic, float roughness )
{
   float3 output = GlowIntensity.xyz;
#ifdef ENABLE_PULSE_HIGHLIGHTING
   output *= abs(sin(time*PULSE_HIGHLIGHTING_SPEED)); // abs(sintime);
#endif
   #ifdef SKIPIFNODYNAMICLIGHTS
   if ( g_lights_data.x == 0 ) return output;
   #endif

    // light 0
    float3 toLight = g_lights_pos0.xyz - worldPos;
    float lightDist = length( toLight );
    float fAtten;
    float3 lightDir;
    float3 halfvec;
    float4 lit0;
	float4 local_lights_atten0 = float4(1.0, 1.0/g_lights_pos0.w, 1.0/(g_lights_pos0.w*g_lights_pos0.w), 0.0);

	fAtten = 1.0/dot( local_lights_atten0, float4(1,lightDist,lightDist*lightDist,0) );
	lightDir = normalize( toLight );
	halfvec = normalize(Vn + lightDir);
	lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 

	float3 albedoAdd = float3(1.0,1.0,1.0);
	float3 fspecular = CookTorranceSpecFactor(Nb, toEye, metallic, roughness, -lightDir, albedoAdd);
	fspecular = clamp( ( fspecular * TotalSpecular)  ,0.0,1.0);
  
    output+= (lit0.y *g_lights_diffuse0.xyz * fAtten * 1.7*diffusemap) + (fspecular * g_lights_diffuse0.xyz * fAtten  );   

    // light 1
    toLight = g_lights_pos1.xyz - worldPos;
    lightDist = length( toLight );
	float4 local_lights_atten1 = float4(1.0, 1.0/g_lights_pos1.w, 1.0/(g_lights_pos1.w*g_lights_pos1.w), 0.0);
	fAtten = 1.0/dot( local_lights_atten1, float4(1,lightDist,lightDist*lightDist,0) );
	lightDir = normalize( toLight );
	halfvec = normalize(Vn + lightDir);
	lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 

	fspecular = CookTorranceSpecFactor(Nb, toEye, metallic, roughness, -lightDir, albedoAdd);
	fspecular = clamp( ( fspecular * TotalSpecular) ,0.0,1.0);

    output+= (lit0.y *g_lights_diffuse1.xyz * fAtten * 1.7*diffusemap) + (fspecular * g_lights_diffuse1.xyz * fAtten  );   

	// light 2
	toLight = g_lights_pos2.xyz - worldPos;
	lightDist = length( toLight );
	float4 local_lights_atten2 = float4(1.0, 1.0/g_lights_pos2.w, 1.0/(g_lights_pos2.w*g_lights_pos2.w), 0.0);
	fAtten = 1.0/dot( local_lights_atten2, float4(1,lightDist,lightDist*lightDist,0) );
	lightDir = normalize( toLight );
	halfvec = normalize(Vn + lightDir);
	lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 

	fspecular = CookTorranceSpecFactor(Nb, toEye, metallic, roughness, -lightDir, albedoAdd);
	fspecular = clamp( ( fspecular * TotalSpecular)  ,0.0,1.0);

    output+= (lit0.y *g_lights_diffuse2.xyz * fAtten * 1.7*diffusemap) + (fspecular * g_lights_diffuse2.xyz * fAtten  );   

	// return final light influence
	return output;
}


float3 CalcLighting(float3 Nb, float3 worldPos, float3 Vn, float3 diffusemap, float3 specmap)
{
   float3 output = GlowIntensity.xyz;
#ifdef ENABLE_PULSE_HIGHLIGHTING
   output *= abs(sin(time*PULSE_HIGHLIGHTING_SPEED)); // abs(sintime);
#endif
   #ifdef SKIPIFNODYNAMICLIGHTS
   if ( g_lights_data.x == 0 ) return output;
   #endif

    // light 0
    float3 toLight = g_lights_pos0.xyz - worldPos;
    float lightDist = length( toLight );
    float fAtten;
    float3 lightDir;
    float3 halfvec;
    float4 lit0;
   float4 local_lights_atten0 = float4(1.0, 1.0/g_lights_pos0.w, 1.0/(g_lights_pos0.w*g_lights_pos0.w), 0.0);
   fAtten = 1.0/dot( local_lights_atten0, float4(1,lightDist,lightDist*lightDist,0) );
   lightDir = normalize( toLight );
   halfvec = normalize(Vn + lightDir);
   lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 
   output+= (lit0.y *g_lights_diffuse0.xyz * fAtten * 1.7*diffusemap) + (lit0.z * g_lights_diffuse0.xyz * fAtten * specmap );   
   
    // light 1
    toLight = g_lights_pos1.xyz - worldPos;
    lightDist = length( toLight );
   float4 local_lights_atten1 = float4(1.0, 1.0/g_lights_pos1.w, 1.0/(g_lights_pos1.w*g_lights_pos1.w), 0.0);
   fAtten = 1.0/dot( local_lights_atten1, float4(1,lightDist,lightDist*lightDist,0) );
   lightDir = normalize( toLight );
   halfvec = normalize(Vn + lightDir);
   lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 
   output+= (lit0.y *g_lights_diffuse1.xyz * fAtten * 1.7*diffusemap) + (lit0.z * g_lights_diffuse1.xyz * fAtten * specmap );   
   
    // light 2
    toLight = g_lights_pos2.xyz - worldPos;
    lightDist = length( toLight );
   float4 local_lights_atten2 = float4(1.0, 1.0/g_lights_pos2.w, 1.0/(g_lights_pos2.w*g_lights_pos2.w), 0.0);
   fAtten = 1.0/dot( local_lights_atten2, float4(1,lightDist,lightDist*lightDist,0) );
   lightDir = normalize( toLight );
   halfvec = normalize(Vn + lightDir);
   lit0 = lit(dot(lightDir,Nb),dot(halfvec,Nb),24); 
   output+= (lit0.y *g_lights_diffuse2.xyz * fAtten * 1.7*diffusemap) + (lit0.z * g_lights_diffuse2.xyz * fAtten * specmap );   
   
   // return final light influence
    return output;
}

float4 PSMainCore(in VSOutput input, uniform int fullshadowsoreditor)
{  
   // clipplane can remove pixels   
   clip(input.clip);
   
   // inverse of camera view holds true camera position
   float3 trueCameraPosition = float3(ViewInv._m30,ViewInv._m31,ViewInv._m32);
//   float3 trueCameraPosition = input.cameraPosition; //PE: interpolated not as good , switch back for now.

#ifndef PBRTERRAIN
   TotalSpecular = GlobalSpecular * clamp(((SpecularOverride - 1.0) * 0.25), 0.0, 20.0);
   //TotalSpecular = 1.0 * clamp(((SpecularOverride - 1.0) * 0.25), 0.0, 20.0); //temp test
#else
   TotalSpecular = 2.0 * GlobalSpecular;
#endif

   // put input data into attributes structure
   Attributes attributes;
   attributes.position = input.position.xyz;
   attributes.uv = input.uv;
   attributes.normal = input.normal;
   #ifndef PBRVEGETATION
    attributes.binormal = input.binormal;
    attributes.tangent = input.tangent;
   #endif
      
   // terrain or entity
   #ifdef PBRVEGETATION
    float4 rawdiffusemap = AlbedoMap.Sample(SampleWrap, attributes.uv);
    float3 rawnormalmap = float3(0,0,0);
    float3 rawmetalmap = float3(0,0,0);
    float3 rawglossmap = float3(0,0,0);
   #else
    #ifdef PBRTERRAIN
     // terrain paint R=grass, G=path, B=texture choice
     float4 VegShadowColor = VegShadowSampler.Sample(SampleWrap,attributes.uv/500.0f);
     // atlas lookup for rock texture
     float4 rockdiffusemap = float4(0,0,0,0);
     float3 rocknormalmap = float3(0,0,0);
     #ifdef FASTROCKTEXTURE
      Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*15,0),attributes.uv,rockdiffusemap,rocknormalmap,input.viewDepth);   
     #else
      float3 rockuv = float3(input.position.x,input.position.y,input.position.z)/100.0f;
      float4 cXY = float4(0,0,0,0);
      float4 cYZ = float4(0,0,0,0);
      float4 cXZ = float4(0,0,0,0);
      float3 nXY = float3(0,0,0);
      float3 nXZ = float3(0,0,0);
      float3 nYZ = float3(0,0,0);
      Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*15,0),rockuv.xy,cXY,nXY.xyz,input.viewDepth);   
      Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*15,0),rockuv.xz,cXZ,nXZ.xyz,input.viewDepth);   
      Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*15,0),rockuv.yz,cYZ,nYZ.xyz,input.viewDepth);   
      float mXY = pow(abs(attributes.normal.z),6);
      float mXZ = pow(abs(attributes.normal.y),2);
      float mYZ = pow(abs(attributes.normal.x),6);
      float total = mXY + mXZ + mYZ;
      mXY /= total;
      mXZ /= total;
      mYZ /= total;
      rocknormalmap = nXY*mXY + nXZ *mXZ + nYZ*mYZ;
      rockdiffusemap = cXY*mXY + cXZ * mXZ + cYZ*mYZ;
     #endif	 
	 
     // collect all diffuse/normal contributions
     float4 rawdiffusemap = float4(0,0,0,0);
     float3 rawnormalmap = float3(0,0,0);
     float3 rawmetalmap = float3(0,0,0);
     float3 rawglossmap = float3(0,0,0);
     float4 grass_d = float4(0,0,0,0);
     float3 grass_n = float3(0,0,0);
     float4 sand_d = float4(0,0,0,0);
     float3 sand_n = float3(0,0,0);
     float4 mud_d = float4(0,0,0,0);
     float3 mud_n = float3(0,0,0);
     float4 variation_d = float4(0,0,0,0);
     Atlas16DiffuseLookupCenter(float4(0,0,0.0625*14,0),attributes.uv/16.0,variation_d); // 14   
     #ifdef REMOVEGRASSNORMALS
      Atlas16DiffuseLookupCenterDist(float4(0,0,0.0625*4,0),attributes.uv,grass_d,input.viewDepth);
      grass_n = float3(0.5,0.5,1.0); // 126,128 , neutral normal.
     #else
      Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*4,0),attributes.uv,grass_d,grass_n,input.viewDepth);
     #endif
     rawdiffusemap = grass_d;
     rawnormalmap = grass_n;

     if( variation_d.a >= 0.98 ) 
	 {
         Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*1,0),attributes.uv,sand_d,sand_n,input.viewDepth); // 12
         Atlas16DiffuseNormalLookupCenter(float4(0,0,0.0625*9,0),attributes.uv,mud_d,mud_n,input.viewDepth); // 11
         grass_d = lerp( mud_d ,grass_d, variation_d.r );                                             
         grass_n = lerp( mud_n ,grass_n, variation_d.r );                                             
         rawdiffusemap = grass_d;
         rawnormalmap = grass_n;
         rawnormalmap = lerp(sand_n, rawnormalmap, clamp( ( (input.position.y-520.0f)/40.0f) , 0.0, 1.0) ); // sand normal
         rawdiffusemap = lerp(sand_d, rawdiffusemap, clamp( ( (input.position.y-520.0f)/40.0f) , 0.0, 1.0) ); // sand
     }

     // add last hand drawed textures if exist.
     Atlas16DiffuseNormalLookup(VegShadowColor,attributes.uv,rawdiffusemap,rawnormalmap,input.viewDepth);

     // blend with rock slopes
     rawdiffusemap = lerp(rockdiffusemap, rawdiffusemap, clamp((attributes.normal.y-TERRAINROCKSLOPE )*2.5, 0.0, 1.0) );
     rawnormalmap = lerp(rocknormalmap, rawnormalmap, clamp((attributes.normal.y-TERRAINROCKSLOPE )*2.5, 0.0, 1.0) );
     rawmetalmap = float3(0,0,0);
	 #ifdef NOTERRAINSPECULAR
      rawglossmap = float3(0,0,0);
	 #else
      rawglossmap = float3(rawdiffusemap.w,rawdiffusemap.w,rawdiffusemap.w);
	 #endif
    #else


	 #ifdef USEPARALLAXMAPPING
		
		float amount = ArtFlagControl1.w / 1000.0f; 
		// 0.04 is default of 0 to 0.1 range 
		// per entity adjustment via fpe: parallaxstrength = 40 
		// [TODO: change via UI if/when IMGUI build is public]

		float3 camVec = trueCameraPosition - attributes.position;
		#ifdef WITHANIMATION 
			amount = clamp(amount, 0, 0.01);
		#endif					

		float POMshadowMultiplier = 0;
		if (input.viewDepth < PARALLAX_RANGE) //player view range check to help performance
		{
			float3 surfaceT = normalize(input.tangent);
			float3 binormal = normalize(input.binormal);
			float3x3 TBNPOM = float3x3(surfaceT.xyz, binormal, attributes.normal.xyz);

			float parallaxHeight; 
			attributes.uv = ParallaxOcclusionMapping_Calc(camVec, TBNPOM, amount, attributes.uv, parallaxHeight);

			//calc self shadows for POM
			float3 lightVec = LightSource.xyz;
			float3 L = mul(TBNPOM, normalize(lightVec));

			POMshadowMultiplier = 1 - parallaxSoftShadowMultiplier(L, attributes.uv, parallaxHeight + 0.05, amount);
		}
	
	 #endif

	 float4 rawdiffusemap = AlbedoMap.Sample(SampleWrapLimitLOD, attributes.uv);
     float3 rawnormalmap = NormalMap.Sample(SampleWrap, attributes.uv).rgb;
     float SpecValue = min(MetalnessMap.Sample(SampleWrap, attributes.uv).r, 1);
     float3 rawmetalmap = float3(SpecValue,SpecValue,SpecValue);
     #ifdef AOISAGED
      float GlossValue = 1.0 - (min(AGEDMap.Sample(SampleWrap, attributes.uv).g, 1));
      float3 rawglossmap = float3(GlossValue,GlossValue,GlossValue);
     #else
      float GlossValue = 1.0 - (min(GlossMap.Sample(SampleWrap, attributes.uv).r, 1));
      float3 rawglossmap = float3(GlossValue,GlossValue,GlossValue);
     #endif
    #endif
   #endif


   #ifdef ALPHADISABLED
    rawdiffusemap.a = 1;
   #else
     if( rawdiffusemap.a < ALPHACLIP ) 
     {
       clip(-1);
      return float4(0,0,0,1);
     }
    #ifdef ALPHACLIPNOTRANSPARENCY
     rawdiffusemap.a = 1;
    #endif
   #endif
   
   #ifdef WITHCHARACTERCREATORMASK
    rawdiffusemap = CharacterCreatorDiffuse(rawdiffusemap,attributes.uv);
   #endif
   
   // entity effect control can slice alpha based on a world Y position
   #ifndef PBRTERRAIN
    #ifndef PBRVEGETATION
     if ( fullshadowsoreditor >= 0 )
     {
      float alphaslice = 1.0f - min(1,max(0,input.position.y - EntityEffectControl.x)/50.0f);
      rawdiffusemap.a = rawdiffusemap.a * alphaslice;
      if( alphaslice < 0.4f ) 
      {
         clip(-1);
      }
     }                                                          
    #endif
   #endif
   
   // get normal for pixel
   float3 originalNormal = attributes.normal;
   #ifdef PBRVEGETATION
    attributes.normal = float3(0,1,0);
   #else
    float3x3 toWorld = float3x3(attributes.tangent, attributes.binormal, attributes.normal);
	// allow this to be toggled in the FPE for artist control (could be a way to do this with math, eliminate the IF)
#ifdef PBRTERRAIN
	//PE: Just to remove a branch.
	rawnormalmap.y = 1.0f - rawnormalmap.y;
#else
	if ( ArtFlagControl1.x == 1 )
	{
	  rawnormalmap.y = 1.0f - rawnormalmap.y;
	}  
#endif
    float3 norm = rawnormalmap * 2.0 - 1.0;
    norm = mul(norm.rgb, toWorld);
    attributes.normal = normalize(norm);
   #endif

#ifdef USEPARALLAXMAPPING_2 //disabled
	
	//dot product zero (perpendicular) to one (parallel) 
	float fCanCatchShadow = dot(normalize(LightSource.xyz), attributes.normal.xyz);
	fCanCatchShadow = 1 - abs(fCanCatchShadow);
	POMshadowMultiplier *= fCanCatchShadow;

#endif
   
   // eye vector
   float3 eyeraw = trueCameraPosition - attributes.position;
    
   // apply a detail map when get too close to surface
   #ifdef PBRVEGETATION
     float3 DetailMapRGB = float3(1,1,1);
   #else
    #ifdef PBRTERRAIN
      float3 DetailMapRGB = float3(1,1,1);
    #else
     #ifdef ILLUMINATIONMAP

#ifdef BOOSTILLUM
       //Illumination kind of get lost in the PBR, so also add illum to light and add this boostillum.
       float3 addillum = (IlluminationMap.Sample(SampleWrap,attributes.uv).rgb*1.5);
//       rawdiffusemap.xyz += addillum;
#else
       float3 addillum = IlluminationMap.Sample(SampleWrap,attributes.uv).rgb;
//       rawdiffusemap.xyz += addillum;
#endif
#ifdef LIGHTMAPPED
	   addillum *= 1.5; //PE: illum on lightmapped object need additional boost.
#endif

     #else
	  #ifdef NODETAILMAP
	   // Character Creator characters have no detail map
	  #else
       float detaildistance = 1.0f-min(1,length(eyeraw)/500.0f);
       #ifdef AOISAGED
        float DetailValue = AGEDMap.Sample(SampleWrap,attributes.uv*16.0f).a;
        float3 DetailMapRGB = float3(DetailValue,DetailValue,DetailValue);
       #else
        float3 DetailMapRGB = DetailMap.Sample(SampleWrap,attributes.uv*16.0f).rgb;
       #endif
       DetailMapRGB = lerp(1.0f,DetailMapRGB,detaildistance);
       rawdiffusemap.xyz *= DetailMapRGB;
	  #endif
     #endif
    #endif
   #endif
   
   // Shadows
   int iCurrentCascadeIndex = 0;
   float fShadow = 0.0f;

   if ( fullshadowsoreditor == 1 ) fShadow = GetShadow ( input.viewDepth, input.position, originalNormal, normalize(LightSource.xyz), iCurrentCascadeIndex );

#ifdef USEPARALLAXMAPPING
   POMshadowMultiplier *= ShadowStrength;
   fShadow = clamp(fShadow + POMshadowMultiplier, 0, 1);
#endif

#ifdef CALLEDFROMOLDTERRAIN
#ifdef PBRTERRAIN
	if ( fullshadowsoreditor == 0 ) {
	  // DynTerShaSampler = AGEDMap , dont work.
	  // Looks like only cascade 3 is working when called from old terrain , terrain_basic.fx
	  fShadow = GetShadowCascade ( 3, input.position, originalNormal, normalize(LightSource.xyz) );
	  float fBlendBetweenCascadesAmount = 1.0f;
	  float fCurrentPixelsBlendBandLocation = 1.0f;
      CalculateBlendAmountForInterval ( 3, input.viewDepth,fCurrentPixelsBlendBandLocation, fBlendBetweenCascadesAmount );
  	  fShadow = lerp( 0.0, fShadow, clamp(fBlendBetweenCascadesAmount,0.0,1.0) );
	}
#endif
#endif

   float visibility =  max ( 1.0f - fShadow, 0 );

   DirectionalLight gDirLight;
   gDirLight.Ambient = float4(1,1,1,1);
   gDirLight.Diffuse = float4(1,1,1,1);
   gDirLight.Specular = float4(1,1,1,1);

#if K_MODEL_PE
   //fit to skybox sun , LightSource.xyz should be set to match 100%.
   gDirLight.Direction = normalize(-LightSource.xyz -  float3(0.0,0.30,0.15) ); // as close as it get for a avg. skybox.
#else
   gDirLight.Direction = normalize(-LightSource.xyz);
#endif
#if K_MODEL_PE
   // remove shadow artifacts on sun side , fade slowly into shadow.
//   visibility = lerp(1.0,visibility,clamp(dot(-gDirLight.Direction,attributes.normal)-0.10,0.0,1.0) ); // slowly fade away shadow on light side of objects.
   visibility = lerp(1.0,visibility,clamp(dot(-gDirLight.Direction,attributes.normal)+0.10,0.0,1.0) ); // slowly fade away shadow on light side of objects.
   //PE: todo - GetShadow remove shadow on dark side , but reflection objects dont always have "lowligt" on dark side , so...
#endif

   #ifdef LIGHTMAPPED
    float rawaovalue = 1.0f;
   #else
    #ifdef PBRVEGETATION
     float rawaovalue = 1.0f;
    #else
     #ifdef PBRTERRAIN
      float rawaovalue = 1.0f;
     #else 
	  #ifdef AOISAGED
	   float rawaovalue = AGEDMap.Sample(SampleWrap,attributes.uv).x;
	  #else
	   #ifdef NOAOMAP
        float rawaovalue = 1.0f;
	   #else
        float rawaovalue = AOMap.Sample(SampleWrap,attributes.uv).x;
	   #endif
	  #endif
	  visibility -= ((1.0f-rawaovalue)*visibility);
	 #endif
    #endif
   #endif
   
   float4 originalrawdiffusemap = rawdiffusemap;
   #ifdef LIGHTMAPPED
    // get lightmap image
    float3 rawlightmap = AOMap.Sample(SampleWrap,input.uv2).xyz;
    // remove lightmapper blur artifacts
    rawlightmap = clamp(rawlightmap,0.1,1.0);
    // intensity lightmapper to match realtime PBR albedo
    rawlightmap = (((rawlightmap-0.5)*1.5)+0.5) * 2;
    // produced final light-color
	rawdiffusemap.xyz = rawdiffusemap.xyz * rawlightmap;
   #endif
   
   Material gMaterial;
   gMaterial.Ambient = float4(1,1,1,1);
   gMaterial.Diffuse = rawdiffusemap;
   
   gMaterial.Specular = float4(1,1,1,1);
   gMaterial.Properties.r = 1.0f; //r = reflectance
   gMaterial.Properties.g = rawmetalmap.r; //g = metallic
   gMaterial.Properties.b = 1.0f-rawglossmap.r; //b = roughness

   float3 inputnormalW = attributes.normal;
   float3 toEye = trueCameraPosition - attributes.position;
   float distToEye = length(toEye);
   toEye /= distToEye;
   float3 refVec = reflect(-toEye, inputnormalW);
   float mipIndex = min(9.0f,gMaterial.Properties.b * 12.0f);

   float4 texColor = float4(1, 1, 1, 1);
   float3 irradiance = float3(1, 1, 1);
   float3 envMap = float3(1, 1, 1);
   texColor = rawdiffusemap;
   irradiance = float3(1,1,1);//gIrradiance.Sample(samAnisotropic, inputnormalW);
   envMap = EnvironmentMap.SampleLevel(SampleWrap, refVec, mipIndex).xyz;
   float4 ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
   float4 diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
   //float4 specular = float4(0.0f, 0.0f, 0.0f, 0.0f);
   float4 litColor;
   float lightIntensity = GlobalSurfaceIntensity;
   float att = 0.4;
   float ambientIntensity = AmbiColorOverride.x;

#if K_MODEL_PE

	//PE: Artist is loosing control if we use roughtness as metalness.
	//UE4: put details in metalness.
	//Unity: put details in gloss.
	//We must support both ways.
	
	//float reflectionIntensity = clamp((gMaterial.Properties.g+(rawglossmap.r)) * 0.52,0.0,1.0);

	// PE: Lee the above way is wrong but works for now, only because you made this line below:
	// float3 envFresnel = lerp(0.04f, texColor.rgb, gMaterial.Properties.g);
	// So keep that line :)
   
    //PE: We should only use metalness, but cant currently , more need to be changed in other places.
    float reflectionIntensity = gMaterial.Properties.g;

#else
    //PE: Problem with fading from metal 1 to metal 0.999 gives a huge jump.
    float refAtt = 1.0f - gMaterial.Properties.b;
    float reflectionIntensity = gMaterial.Properties.r * refAtt;
    if (gMaterial.Properties.g >= 1.0f)
    {
      reflectionIntensity = 1.0f;
    }
#endif

	// lighting system (migrate entirely at some point to support spot and point)
	float3 albedo = texColor.rgb - texColor.rgb * (gMaterial.Properties.g); //metallic
	float3 light = ComputeLight(gMaterial, gDirLight, inputnormalW, toEye, albedo.rgb);
	float3 eye = normalize(eyeraw);
	//float3 spotflashlighting = CalcSpotFlash(inputnormalW,attributes.position.xyz);   
	float3 spotflashlighting = float3(0.0,0.0,0.0);

	float3 dynlight = float3(0.0,0.0,0.0);

#ifdef DYNAMICPBRLIGHT
#ifndef PBRTERRAIN
////	light += CalcLightingPBR(inputnormalW,attributes.position.xyz,eye,rawdiffusemap.xyz,float3(0,0,0), toEye, gMaterial.Properties.g, gMaterial.Properties.b ) + spotflashlighting;  
//	light += input.VertexLight.xyz * 1.7 * rawdiffusemap.xyz;
	dynlight += CalcExtLightingPBR(inputnormalW,attributes.position.xyz,eye,rawdiffusemap.xyz,float3(0,0,0), toEye, gMaterial.Properties.g, gMaterial.Properties.b ) + spotflashlighting + (input.VertexLight.xyz * 2.0 * rawdiffusemap.xyz);

#else
//	light += CalcLighting(inputnormalW,attributes.position.xyz,eye,rawdiffusemap.xyz,float3(0,0,0)) + spotflashlighting;  
////	light += CalcExtLighting(inputnormalW,attributes.position.xyz,eye,rawdiffusemap.xyz,float3(0,0,0)) + spotflashlighting;
//	light += input.VertexLight.xyz * 1.7 * rawdiffusemap.xyz;
	dynlight += CalcExtLightingPBR(inputnormalW,attributes.position.xyz,eye,rawdiffusemap.xyz,float3(0,0,0), toEye, gMaterial.Properties.g, gMaterial.Properties.b ) + spotflashlighting + (input.VertexLight.xyz * 2.0 * rawdiffusemap.xyz);  


#endif
#else
	dynlight += CalcLighting(inputnormalW,attributes.position.xyz,eye,rawdiffusemap.xyz,float3(0,0,0)) + spotflashlighting;  
#endif

	//float flashlight = CalcFlashLight(attributes.position.xyz);

    // flash light system (flash light control carried in SpotFlashColor.w )
    //PE: eyePos ? cameraPosition ? wrong ?
    //PE: float4 eyePos : CameraPosition;
	//LEE: corrected camera position (now using ViewInv and stored in trueCameraPosition)
    //PE: Looks like when water reflection is active this is set wrong , also ruin PBR light.
	float4 viewspacePos = mul(float4(attributes.position.xyz,1), View);
    float conewidth = 24;
    float intensity = max(0, 1.5f - (viewspacePos.z/500.0f));
    float3 lightdir = float3(View._m02,View._m12,View._m22);
	
#ifndef REFLECTIVEFLASHLIGHT
    float flashlight = pow(max( dot(-eye, lightdir)  ,0),conewidth) * intensity * SpotFlashColor.w * MAXFLASHLIGHT; 
#else
    //PE: This code let you see the reflection of the flashlight in metal objects, wip:
	float3 albedoAdd = float3(1.0,1.0,1.0);
	float3 fspecular = CookTorranceSpecFactor(inputnormalW, toEye, gMaterial.Properties.g, gMaterial.Properties.b, lightdir, albedoAdd);
	fspecular = clamp( ( fspecular * TotalSpecular) + dot(-eye, lightdir) ,0.0,1.0);
    float flashlight = pow(max(fspecular.r,0),conewidth) * intensity * SpotFlashColor.w * MAXFLASHLIGHT;
#endif

#ifndef PBRTERRAIN
    #ifdef SPECULARCAMERA
     float4 lightingsc = lit(dot(eye,inputnormalW),dot(eye,inputnormalW),24);
     //intensity = max(0, 1.5f - (viewspacePos.z/500.0f));
     lightingsc.z = lightingsc.z * intensity;
     light =  light + ( ( (lightingsc.z * SPECULARCAMERAINTENSITY ) * SurfColor.xyz * visibility * TotalSpecular) * 0.5);
    #endif
#endif
    
//	visibility = clamp( visibility+(flashlight*0.75) , 0.0 ,1.0 );
	visibility = clamp( visibility+(flashlight*0.75) , 0.15 ,1.0 ); //PE: Set lowest dark shadow, to stop uneven shadow colors.
	//PE: Allow dyn light to remove shadow.
	visibility = clamp( visibility+( length(dynlight) ) , 0.15 ,1.0 ); //PE: Set lowest dark shadow, to stop uneven shadow colors.
	
	light = light + dynlight;

	//light += (rawdiffusemap.xyz) * flashlight);


	// work out environmental fresnel
	float3 envFresnel = lerp(0.02f, texColor.rgb, gMaterial.Properties.g);
	
	// can boost 
	#ifdef BOOSTINTENSITY
	 ambientIntensity *= (1.0f+ArtFlagControl1.z);
	 lightIntensity *= (1.0f+ArtFlagControl1.z);
	#endif

	// work out contributions
#ifdef LIGHTMAPPED
	 //PE: Use original diffuse (lightmap already have shadows in rawdiffusemap).
	 float3 flashlightContrib = originalrawdiffusemap.xyz * flashlight;
#else
	 float3 flashlightContrib = rawdiffusemap.xyz * flashlight;
#endif
	#ifndef PBRTERRAIN
	 ambientIntensity *= AmbientPBRAdd; //PE: Some ambient is lost in PBR. make it look more like terrain.
	#endif
	float3 albedoContrib = originalrawdiffusemap.rgb * irradiance * AmbiColor.xyz * ambientIntensity * (0.5f+(visibility*0.5));
	
	float3 lightContrib = ((max(float3(0,0,0),light) * lightIntensity)+flashlightContrib) * SurfColor.xyz * visibility;
   	float3 reflectiveContrib = envMap * envFresnel * reflectionIntensity * (0.5f+(visibility/2.0f));


#ifdef PBRTERRAIN
   litColor.rgb = albedoContrib + lightContrib + reflectiveContrib;
#else
#ifdef PBRVEGETATION
   litColor.rgb = albedoContrib + lightContrib + reflectiveContrib;
#else

#ifdef ILLUMINATIONMAP
	//PE: i use * here to prepare for baking textures like illum.
    albedoContrib += (texColor.rgb*(addillum));
    //PE: Illum kind of lost in PBR , so boost a bit.
    lightContrib += (texColor.rgb*(addillum));
#endif    

#if K_MODEL_PE

	//TODO: add more to glass: - (1.0 -(gMaterial.Diffuse.a * texColor.a))
    float env_ref_fresnel = pow( max( 1.0-dot( normalize(trueCameraPosition - attributes.position) , inputnormalW), 0.0f) , 2.0 ) * 0.85 + 0.65; //
	env_ref_fresnel = clamp(env_ref_fresnel+gMaterial.Properties.g,0.0,1.0);
	reflectiveContrib.rgb = reflectiveContrib.rgb * env_ref_fresnel;
	
	float3 cooleffect = lerp( (albedoContrib + lightContrib + reflectiveContrib.rgb) * ((dot(-gDirLight.Direction, normalize(inputnormalW) )*0.40)+0.60) , albedoContrib + lightContrib + reflectiveContrib.rgb , RealisticVsCool );

	float extractedReflections = clamp(clamp( ( (length(envMap.rgb)  )* AmountExtractLight )-0.70,0.0,1.0)*3.45,0.0,1.0);
	litColor.rgb = lerp( cooleffect , (envMap.rgb + ( lightContrib.rgb)) * env_ref_fresnel , extractedReflections * (envFresnel*0.40+0.6) );

	//Debug:
	//litColor.rgb = float3( env_ref_fresnel,env_ref_fresnel,env_ref_fresnel );
	//litColor.rgb = float3(rawglossmap.r,rawglossmap.r,rawglossmap.r);
	//litColor.rgb = ComputeLight(gMaterial, gDirLight, inputnormalW, toEye, albedo.rgb);
	//litColor.rgb = float3(gMaterial.Properties.g,gMaterial.Properties.g,gMaterial.Properties.g);
	//litColor.rgb = envMap;
	
#else
   litColor.rgb = albedoContrib + lightContrib + reflectiveContrib;
#endif


#endif
#endif   
    // calculate hud pixel-fog
    float4 cameraPos = mul(float4(attributes.position.xyz,1), View);
    float hudfogfactor = saturate((cameraPos.z-HudFogDist.x)/(HudFogDist.y-HudFogDist.x));
    float4 hudfogresult = lerp(litColor,float4(HudFogColor.xyz,0),hudfogfactor*HudFogColor.w);
   litColor.xyz = hudfogresult.xyz;

    // apply alpha to final pixel color   
   litColor.a = gMaterial.Diffuse.a * texColor.a;
   
    // lime green tint to show where grass is being painted and highlight control (editor control)
   #ifdef PBRTERRAIN
     float fVeg = VegShadowColor.r;
     litColor.xyz = litColor.xyz + float3(HighlightParams.y/8.0f,HighlightParams.y/2.0,HighlightParams.y/8.0f) * fVeg;
     float highlightsize = (1.0f/HighlightCursor.z)*25600.0f;
     float2 highlightuv = (((attributes.uv/500.0f)-float2(0.5f,0.5f))*highlightsize) + float2(0.5f,0.5f) - (HighlightCursor.xy/(HighlightCursor.z*0.0195));
     float4 highlighttex = HighlighterSampler.SampleLevel(SampleClamp,highlightuv,0);
     float highlightalpha = (highlighttex.a*0.5f);
     litColor.xyz = litColor.xyz + (HighlightParams.x*float3(highlightalpha*HighlightParams.z,highlightalpha*HighlightParams.a,0));
   #endif
 
   // combine for final color
   float3 finalColor = litColor.xyz;
    #ifdef DEBUGSHADOW
    finalColor = TintDebugShadow ( iCurrentCascadeIndex, float4(finalColor,1.0) ).rgb;
   #endif
  

   // final render pixel or show PBR debug layer views
   if ( ShaderVariables.x > 0 )
   {

      if ( ShaderVariables.x == 1 ) { finalColor = rawdiffusemap.rgb; }
      if ( ShaderVariables.x == 2 ) { finalColor = attributes.normal; }
      if ( ShaderVariables.x == 3 ) { finalColor = rawmetalmap; }
      if ( ShaderVariables.x == 4 ) { finalColor = rawglossmap; }
      #ifdef LIGHTMAPPED
       if ( ShaderVariables.x == 5 ) { finalColor = rawlightmap; }
      #else
       if ( ShaderVariables.x == 5 ) { finalColor = float3(rawaovalue,rawaovalue,rawaovalue); }
      #endif
      if ( ShaderVariables.x == 6 ) { finalColor = albedoContrib; }
      if ( ShaderVariables.x == 7 ) { finalColor = lightContrib; }
      if ( ShaderVariables.x == 8 ) { finalColor = reflectiveContrib; }
#ifdef ILLUMINATIONMAP
      if ( ShaderVariables.x == 9 ) { finalColor = addillum; }
#else
      if ( ShaderVariables.x == 9 ) { finalColor = float3(fShadow,fShadow,fShadow); }
#endif

      litColor.a = 1;
   }
   
   // grass can fade out at distance
   #ifdef PBRVEGETATION
    litColor.a *= input.color.a;
   #endif
   
   // and also apply any alpha override
   #ifndef PBRTERRAIN
    #ifndef PBRVEGETATION
	 // including fAlphaOverride from constant buffer (non-instanced alphad objects)
     litColor.a *= AlphaOverride * fAlphaOverride;
    #endif
   #endif

   // final pixel color and alpha
   return float4(finalColor, litColor.a);
}

float4 depthPS(in VSOutput input) : SV_TARGET
{
   clip(input.clip);
   float4 rawdiffusemap = AlbedoMap.Sample(SampleWrap, input.uv);
#ifdef ALPHADISABLED
    rawdiffusemap.a = 1;
#else

#ifdef SHADOWALPHACLIP
   if( rawdiffusemap.a < SHADOWALPHACLIP ) 
   {
      clip(-1);
      return rawdiffusemap;
   }
#else
   if( rawdiffusemap.a < ALPHACLIP ) 
   {
      clip(-1);
      return rawdiffusemap;
   }
#endif
#endif
   return rawdiffusemap;
}


float4 PSMain(in VSOutput input, uniform int fullshadowsoreditor) : SV_TARGET
{
	float4 final = PSMainCore(input,fullshadowsoreditor); 
	return final;
}

float4 PSMainBaked(in VSOutput input, uniform int fullshadowsoreditor) : SV_TARGET
{
	float4 final = PSMainCore(input,fullshadowsoreditor); 
	return final;
}

float4 blackPS(in VSOutput input) : SV_TARGET
{
   clip(input.clip);
   return float4(0,0,0,1);
}

DepthStencilState YesDepthRead
{
  DepthFunc = LESS_EQUAL;
};
DepthStencilState NoDepthRead
{
  DepthFunc = ALWAYS;
};
RasterizerState ForwardCull 
{
  FrontCounterClockwise = TRUE;
};
RasterizerState BackwardCull 
{
  FrontCounterClockwise = FALSE;
};
#ifdef CUTINTODEPTHBUFFER
technique11 CutOutDepth
{
   pass CutOutDepth
   {      
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(0)));
        SetGeometryShader(NULL);
        SetDepthStencilState( NoDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
   }
}
#endif

technique11 Highest
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 High
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 Medium
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
#ifdef CALLEDFROMOLDTERRAIN
        SetPixelShader(CompileShader(ps_5_0, PSMain(0))); // 0 for in editor. (DynTerShaSampler not set so must be 1 for now. )
#else
        SetPixelShader(CompileShader(ps_5_0, PSMain(1))); // 0 for in editor. (DynTerShaSampler not set so must be 1 for now. )
#endif
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 Lowest
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(-1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 LowestWithCutOutDepth
{
    pass CutOutPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(-1)));
        SetGeometryShader(NULL);
        SetDepthStencilState( NoDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
    }
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(-1)));
        SetGeometryShader(NULL);
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
    }
}

technique11 Highest_Prebake
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMainBaked(1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 High_Prebake
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMainBaked(1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 Medium_Prebake
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMainBaked(0)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 Lowest_Prebake
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, PSMainBaked(-1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

#ifdef PBRTERRAIN
technique11 DepthMap
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(NULL);
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}
#else
technique11 DepthMap
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(1))); //PE: I dont see this RT warning, so made a depthPS() only using albedo ?.
        SetPixelShader(CompileShader(ps_5_0, depthPS())); //causes RT warning when used to render depth(shadows) only! 
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}
#endif

technique11 DepthMapNoAnim
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(0)));
        SetPixelShader(NULL);
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 Distant
{
    pass MainPass
    {
        SetVertexShader(CompileShader(vs_5_0, VSMain(0)));
        SetPixelShader(CompileShader(ps_5_0, PSMain(-1)));
        SetGeometryShader(NULL);
        #ifdef CUTINTODEPTHBUFFER
        SetDepthStencilState( YesDepthRead, 0 );
        SetRasterizerState ( BackwardCull );
        #endif
    }
}

technique11 blacktextured
{
    pass P0
    {
		SetVertexShader(CompileShader(vs_5_0, VSMain(1)));
        SetPixelShader(CompileShader(ps_5_0, blackPS()));
        SetGeometryShader(NULL);
    }
}


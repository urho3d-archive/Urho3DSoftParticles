#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Fog.glsl"

#ifdef COMPILEPS
uniform float cDepthDiffMult;
uniform bool cAddBlending;
#endif

varying vec2 vTexCoord;
varying vec4 vWorldPos;
varying vec4 vScreenPos;
#ifdef VERTEXCOLOR
    varying vec4 vColor;
#endif

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetTexCoord(iTexCoord);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    vScreenPos = GetScreenPos(gl_Position);

    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif
}

void PS()
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        vec4 diffColor = cMatDiffColor * texture2D(sDiffMap, vTexCoord);
        #ifdef ALPHAMASK
            if (diffColor.a < 0.5)
                discard;
        #endif
    #else
        vec4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= vColor;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(vWorldPos.w, vWorldPos.y);
    #else
        float fogFactor = GetFogFactor(vWorldPos.w);
    #endif

    #if defined(PREPASS)
        // Fill light pre-pass G-Buffer
        gl_FragData[0] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[1] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #elif defined(DEFERRED)
        gl_FragData[0] = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
        gl_FragData[2] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[3] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #else

        float particleDepth = vWorldPos.w;
        float solidGeometryDepth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r); // use ReconstructDepth when HWDEPTH
    
        if (solidGeometryDepth <= particleDepth)
        {
            float deltaDepth = (particleDepth - solidGeometryDepth) * cDepthDiffMult;
            if (cAddBlending)
                diffColor.rgb -= deltaDepth;
            else
                diffColor.a -= deltaDepth;
        }
    
        gl_FragColor = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
    
    #endif
}

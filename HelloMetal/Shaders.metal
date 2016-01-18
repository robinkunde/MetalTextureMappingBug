//
//  Shaders.metal
//  HelloMetal
//
//  Created by Main Account on 10/2/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn{
    packed_float3 position;
    packed_float4 color;
    packed_float2 texCoord;
};

struct VertexOut{
    float4 position [[position]];
    float4 color;
    float2 texCoord;
};

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut basic_vertex(device VertexIn* vertex_array [[ buffer(0) ]],
                              constant Uniforms&  uniforms    [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {

    float4x4 mv_Matrix = uniforms.modelMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    VertexIn VertexIn = vertex_array[vid];

    VertexOut VertexOut;
    VertexOut.position = proj_Matrix * mv_Matrix * float4(VertexIn.position, 1);
    VertexOut.color = VertexIn.color;

#define USE_LOOKUP_FIX 0
#if USE_LOOKUP_FIX
#define offsetof(st, m) ((size_t)(&((constant st *)0)->m))
    device float *floats = (device float *)vertex_array;
    size_t vertexSizeInFloats = sizeof(struct VertexIn) / sizeof(float);
    size_t texCoordOffsetInFloats = offsetof(struct VertexIn, texCoord)/ sizeof(float);
    device float *texCoordDirect = floats + (vid * vertexSizeInFloats + texCoordOffsetInFloats);
    device packed_float2 *texCoordArr = (device packed_float2 *)texCoordDirect;
    float2 texCoords = texCoordArr[0];
    VertexOut.texCoord = texCoords;
#else
    VertexOut.texCoord = VertexIn.texCoord;
#endif

    return VertexOut;
}

fragment float4 basic_fragment(VertexOut interpolated [[stage_in]],
                               texture2d<float>  tex2D     [[ texture(0) ]],
                               sampler           sampler2D [[ sampler(0) ]]) {

    float4 color = tex2D.sample(sampler2D, interpolated.texCoord);
    return color;
}

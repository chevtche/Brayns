/* Copyright (c) 2019, EPFL/Blue Brain Project
 * All rights reserved. Do not distribute without permission.
 *
 * This file is part of Brayns <https://github.com/BlueBrain/Brayns>
 *
 * This library is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License version 3.0 as published
 * by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "../Helpers.h"
#include "../Random.h"
#include "../../CommonStructs.h"
#include <optix.h>
#include <optixu/optixu_math_namespace.h>
#include <optixu/optixu_matrix_namespace.h>

static const float OPENDECK_RADIUS = 2.55f;
static const float OPENDECK_HEIGHT = 2.3f;
static const float OPENDECK_METALSTRIPE_HEIGHT = 0.045f;
static const float HALF_IDP = 0.065f / 2.0f;
static const float PI = 3.141592f;
static const float OPENDECK_BEZEL_ANGLE = PI / 180.0f * 7.98995f;
static const float ANGLE_PER_BORDER_SEGMENT = (PI - 8.0f * OPENDECK_BEZEL_ANGLE) / 7.0f + OPENDECK_BEZEL_ANGLE;
static const float FULL_ANGLE = ANGLE_PER_BORDER_SEGMENT + OPENDECK_BEZEL_ANGLE;   

using namespace optix;

rtDeclareVariable(unsigned int, segmentID, , ); //even segmentsID are right eye buffers and odd are left eye buffers
rtDeclareVariable(float3, headPos, , );
rtDeclareVariable(float3, headUVec, , );

rtDeclareVariable(float3, eye, , );
rtDeclareVariable(float3, U, , );
rtDeclareVariable(float3, V, , );
rtDeclareVariable(float3, W, , );
rtDeclareVariable(float3, bad_color, , );
rtDeclareVariable(float, scene_epsilon, , );
rtBuffer<uchar4, 2> output_buffer;
rtBuffer<float4, 2> accum_buffer;
rtDeclareVariable(rtObject, top_object, , );
rtDeclareVariable(unsigned int, radiance_ray_type, , );
rtDeclareVariable(unsigned int, frame, , );
rtDeclareVariable(uint2, launch_index, rtLaunchIndex, );

rtDeclareVariable(float, aperture_radius, , );
rtDeclareVariable(float, focal_scale, , );
rtDeclareVariable(float4, jitter4, , );
rtDeclareVariable(unsigned int, samples_per_pixel, , );

rtBuffer<float4, 1> clip_planes;
rtDeclareVariable(unsigned int, nb_clip_planes, , );

__device__ void getClippingValues(const float3& ray_origin,
                                  const float3& ray_direction, float& near,
                                  float& far)
{
    for (int i = 0; i < nb_clip_planes; ++i)
    {
        float4 clipPlane = clip_planes[i];
        const float3 planeNormal = {clipPlane.x, clipPlane.y, clipPlane.z};
        float rn = dot(ray_direction, planeNormal);
        if (rn == 0.f)
            rn = scene_epsilon;
        float d = clipPlane.w;
        float t = -(dot(planeNormal, ray_origin) + d) / rn;
        if (rn > 0.f) // opposite direction plane
            near = max(near, t);
        else
            far = min(far, t);
    }
}

// Pass 'seed' by reference to keep randomness state
__device__ float3 launch(unsigned int& seed, const float2 screen,
                         const bool use_randomness)
{
    float eyeDelta = 0.0f;
    float alpha = 0.0f;
    float3 dPx, dPy;

    float2 sample = make_float2(launch_index) / screen;    

    if (segmentID <= 13 && segmentID % 2 == 0)
    {
        eyeDelta = HALF_IDP;
        unsigned int angularOffset = segmentID / 2;

        if(segmentID == 0)
            alpha = sample.x * FULL_ANGLE;
        else if(segmentID == 12)
            alpha = PI - FULL_ANGLE + sample.x * FULL_ANGLE;
        else
            alpha = angularOffset * (FULL_ANGLE - OPENDECK_BEZEL_ANGLE)  + sample.x * FULL_ANGLE;
    }
    else if (segmentID <= 13 && segmentID % 2 == 1)
    {
        eyeDelta = -HALF_IDP;
        unsigned int angularOffset = segmentID / 2;
        if( segmentID == 1)
            alpha = sample.x * FULL_ANGLE;
        else if(segmentID == 13)
            alpha = PI - FULL_ANGLE + sample.x * FULL_ANGLE;
        else
            alpha = angularOffset * (FULL_ANGLE - OPENDECK_BEZEL_ANGLE)  + sample.x * FULL_ANGLE;
    }
    else if (segmentID == 14)
    {
        eyeDelta = HALF_IDP;
    }
    else if (segmentID == 15)
    {
        eyeDelta = -HALF_IDP;
    }

    float3 pixelPos;
    if (segmentID <= 13)
    {
        pixelPos.x = OPENDECK_RADIUS * -cosf(alpha);
        //pixelPos.y = OPENDECK_METALSTRIPE_HEIGHT + OPENDECK_HEIGHT * (sample.y);
        pixelPos.y = OPENDECK_METALSTRIPE_HEIGHT +
                     OPENDECK_HEIGHT - OPENDECK_HEIGHT * sample.y;
        pixelPos.z = OPENDECK_RADIUS * -sinf(alpha);

        dPx = make_float3(FULL_ANGLE * OPENDECK_RADIUS * sinf(alpha), 0.0f, FULL_ANGLE * OPENDECK_RADIUS * cosf(alpha));
        dPy = make_float3(0.0f, -OPENDECK_HEIGHT, 0.0f); 
    }
    else if (segmentID > 13)
    {
        pixelPos.x = 2.0f * OPENDECK_RADIUS * (sample.x - 0.5f);
        pixelPos.y = 0.0f;
        pixelPos.z = -OPENDECK_RADIUS + OPENDECK_RADIUS * sample.y;
        // pixelPos.z = -OPENDECK_RADIUS * screen.y;

        dPx = make_float3(2.0f * OPENDECK_RADIUS, 0.0f, 0.0f); 
        dPy = make_float3(0.0f, 0.0f, OPENDECK_RADIUS);
    }

    // The tracking model of the 3d glasses is inversed
    // so we need to negate CamDu here.
    const float3 eyeDeltaPos = -headUVec * eyeDelta;

    optix::Matrix3x3 transform;
    transform.setCol(0,U);
    transform.setCol(1,V);
    transform.setCol(2,W);
    //const LinearSpace3f cameraSpace =
    //    make_LinearSpace3f(self->dir_du, self->dir_dv, self->dir_cam);


    const float3 d = pixelPos - headPos + eyeDeltaPos;
    const float dotD = dot(d,d);
    const float denom = pow(dotD, 1.5f);
    float3 dir = normalize(d);

    float3 dirDx = (dotD * dPx - dot(d,dPx) * d) / (denom * screen.x);
    float3 dirDy = (dotD * dPy - dot(d,dPy) * d) / (denom * screen.y);

    PerRayData_radiance prd;
    prd.importance = 1.f;
    prd.depth = 0;
    prd.rayDdx = transform * dirDx;
    prd.rayDdy = transform * dirDy;
    dir = transform * dir;

    const float3 org = eye + headPos - eyeDeltaPos;
    float near = scene_epsilon;
    float far = INFINITY;

    getClippingValues(org, dir, near, far);
    optix::Ray ray(org, dir, radiance_ray_type, near, far);

    rtTrace(top_object, ray, prd);

    return prd.result;    
}

RT_PROGRAM void cylindricCamera()
{
    const size_t2 screen = output_buffer.size();
    const float2 screen_f = make_float2(screen);

    unsigned int seed =
        tea<16>(screen.x * launch_index.y + launch_index.x, frame);

    const int num_samples = max(1, samples_per_pixel);
    // We enable randomness if we are using subpixel sampling or accumulation
    const bool use_randomness = frame > 0 || num_samples > 1;

    float3 result = make_float3(0, 0, 0);
    for (int i = 0; i < num_samples; i++)
        result += launch(seed, screen_f, use_randomness);
    result /= num_samples;

    float4 acc_val = accum_buffer[launch_index];
    if (frame > 0)
        acc_val = lerp(acc_val, make_float4(result, 0.f),
                       1.0f / static_cast<float>(frame + 1));
    else
        acc_val = make_float4(result, 1.f);

    output_buffer[launch_index] = make_color(make_float3(acc_val));
    accum_buffer[launch_index] = acc_val;
}

RT_PROGRAM void exception()
{
    output_buffer[launch_index] = make_color(bad_color);
}

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

#include "AdvancedSimulation.h"
#include <optix.h>
#include <optixu/optixu_math_namespace.h>

using namespace optix;

// Material attributes
rtDeclareVariable(float3, Ka, , );
rtDeclareVariable(float3, Kd, , );
rtDeclareVariable(float3, Ks, , );
rtDeclareVariable(float3, Kr, , );
rtDeclareVariable(float3, Ko, , );
rtDeclareVariable(float, glossiness, , );
rtDeclareVariable(float, refraction_index, , );
rtDeclareVariable(float, phong_exp, , );

rtDeclareVariable(float3, geometric_normal, attribute geometric_normal, );
rtDeclareVariable(float3, shading_normal, attribute shading_normal, );

// Textures
rtTextureSampler<float4, 2> diffuse_map;
rtDeclareVariable(float3, texcoord, attribute texcoord, );

RT_PROGRAM void any_hit_shadow()
{
    phongShadowed(Ko);
}

RT_PROGRAM void closest_hit_radiance()
{
    float3 world_shading_normal =
        normalize(rtTransformNormal(RT_OBJECT_TO_WORLD, shading_normal));
    float3 world_geometric_normal =
        normalize(rtTransformNormal(RT_OBJECT_TO_WORLD, geometric_normal));

    float3 ffnormal = faceforward(world_shading_normal, -ray.direction,
                                  world_geometric_normal);
    phongShade(Kd, Ka, Ks, Kr, Ko, refraction_index, phong_exp, glossiness,
               ffnormal, ray.tmax);
}

RT_PROGRAM void closest_hit_radiance_textured()
{
    float3 world_shading_normal =
        normalize(rtTransformNormal(RT_OBJECT_TO_WORLD, shading_normal));
    float3 world_geometric_normal =
        normalize(rtTransformNormal(RT_OBJECT_TO_WORLD, geometric_normal));

    float3 ffnormal = faceforward(world_shading_normal, -ray.direction,
                                  world_geometric_normal);

    const float3 Kd = make_float3(tex2D(diffuse_map, texcoord.x, texcoord.y));
    phongShade(Kd, Ka, Ks, Kr, Ko, refraction_index, phong_exp, glossiness,
               ffnormal, ray.tmax);
}
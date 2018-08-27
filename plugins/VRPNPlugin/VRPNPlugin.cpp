/* Copyright (c) 2015-2018, EPFL/Blue Brain Project
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

#include "VRPNPlugin.h"
#include <brayns/common/camera/Camera.h>
#include <brayns/pluginapi/PluginAPI.h>
#include <ospray/SDK/camera/PerspectiveCamera.h>  

namespace brayns
{

Vector3f rotateVectorByQuat(const Vector3f& v, const vrpn_float64* q)
{
    // Extract the vector part of the quaternion
    Vector3f u(q[0], q[1], q[2]);

    // Extract the scalar part of the quaternion
    float s = q[3];

    // Do the math
    Vector3f result = 2.0f * vmml::dot(u, v) * u
                      + (s*s - vmml::dot(u, u)) * v
                      + 2.0f * s * vmml::cross(u, v);
    return result;
}

void VRPN_CALLBACK handleTracker(void* userData, const vrpn_TRACKERCB t )
{
    Camera* camera = static_cast<Camera*>(userData);
    camera->updateProperty("openDeckPosition",std::array<float,3>{(float)t.pos[0], (float)t.pos[1], (float)t.pos[2]});

    std::cout << "Quat: " << t.quat[0] <<" "<< t.quat[1] << " " << t.quat[2] << " " << t.quat[3] << std::endl;
   
    Vector3f rightInitial(1.0f, 0.0f, 0.0f);
    Vector3f right = rotateVectorByQuat(rightInitial, t.quat);

    std::cout << "Vector: " << right.x() << " " << right.y() << " " << right.z() << std::endl;

    camera->updateProperty("openDeckCamDU",std::array<float,3>{right.x(), right.y(), right.z()});
}

VRPNPlugin::VRPNPlugin(PluginAPI* api, int argc, char** argv)
    : _api(api)
    , _camera(api->getCamera())
{
    PropertyMap properties;
    PropertyMap::Property openDeckPosition{"openDeckPosition", "openDeckPosition", std::array<float,3>{0.0f, 0.0f, 0.0f}};
    openDeckPosition.markReadOnly();
    properties.setProperty(openDeckPosition);

    PropertyMap::Property openDeckCamDU{"openDeckCamDU", "openDeckCamDU", std::array<float,3>{1.0f, 0.0f, 0.0f}};
    openDeckCamDU.markReadOnly();
    properties.setProperty(openDeckCamDU);


    properties.setProperty({"stereoMode", "Stereo mode", (int)ospray::PerspectiveCamera::StereoMode::OSP_STEREO_SIDE_BY_SIDE,
                           {"None", "Left eye", "Right eye", "Side by side"}});
    properties.setProperty({"interpupillaryDistance", "Eye separation", 0.0635f, {0.f, 10.f}});

    _camera.setProperties("cylindricStereoTracked", properties);
    std::cout << "Got args: ";
    for (int i = 0; i < argc; ++i)
        std::cout << argv[i] << "; ";
    std::cout << std::endl;
}

VRPNPlugin::~VRPNPlugin()
{
    if(_vrpn->joinable())
        _vrpn->join();
}
void VRPNPlugin::preRender()
{
    if(!initialized)
    {
        _vrpnTracker.reset(new vrpn_Tracker_Remote("DTrack@cave1")); 
        _vrpnTracker->register_change_handler(&_camera, handleTracker); 
        _vrpn.reset(new std::thread(&VRPNPlugin::_vrpnListen, this));
        initialized = true;   
    }
}

void VRPNPlugin::postRender()
{
    //std::cout << "Plugin post render" << std::endl;
}

void VRPNPlugin::postSceneLoading()
{
    //std::cout << "Plugin post scene loading" << std::endl;
}

void VRPNPlugin::_vrpnListen()
{
    while(true)
    {
        _vrpnTracker->mainloop();
    }
}

}

extern "C" brayns::ExtensionPlugin* brayns_plugin_create(brayns::PluginAPI* api,
                                                         int argc, char** argv)
{
    return new brayns::VRPNPlugin(api, argc, argv);
}

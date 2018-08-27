# Copyright (c) 2015-2018, EPFL/Blue Brain Project
# All rights reserved. Do not distribute without permission.
#
# This file is part of Brayns <https://github.com/BlueBrain/Brayns>

cmake_minimum_required(VERSION 3.1 FATAL_ERROR)
set(NAME VRPNPLUGIN)
project(${NAME} VERSION 1.0.0)
set(${NAME}_VERSION_ABI 1)

include(Common)

common_find_package(Brayns REQUIRED)
common_find_package(VRPN REQUIRED)
common_find_package_post()

set(${NAME}_SOURCES
  VRPNPlugin.cpp
)

set(${NAME}_PUBLIC_HEADERS
  VRPNPlugin.h
)

set(${NAME}_LINK_LIBRARIES braynsPluginAPI vmmlib ${VRPN_LIBRARIES})

common_library(VRPNPlugin)

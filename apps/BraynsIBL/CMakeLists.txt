# Copyright (c) 2019, EPFL/Blue Brain Project
# All rights reserved. Do not distribute without permission.
#
# This file is part of Brayns <https://github.com/BlueBrain/Brayns>

set(BRAYNSIBL_SOURCES main.cpp)

set(BRAYNSIBL_LINK_LIBRARIES
  ${FREEIMAGE_LIBRARIES}
  ${OPENGL_gl_LIBRARY}
  ${GLEW_LIBRARIES}
  glfw
  glm
)

common_application(braynsIBL)

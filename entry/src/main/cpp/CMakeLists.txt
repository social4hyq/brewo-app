cmake_minimum_required(VERSION 3.5)
project(brewo_bridge)

add_library(brewo_bridge SHARED brewo_bridge.c)

target_include_directories(brewo_bridge PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  $ENV{OHOS_NATIVE_SYSROOT}/usr/include/napi
  $ENV{OHOS_NATIVE_SYSROOT}/usr/include
)

set_target_properties(brewo_bridge PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}
)

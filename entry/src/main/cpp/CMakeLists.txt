cmake_minimum_required(VERSION 3.5.0)
project(opencode_native)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

add_library(opencode_native SHARED
    napi_init.cpp
    process_manager.cpp
)

target_link_libraries(opencode_native PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
)

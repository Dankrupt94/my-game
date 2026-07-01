cmake_minimum_required(VERSION 3.20)

project(acore_godot_protocol LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_filename_component(PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)

set(GODOT_CPP_DIR "${PROJECT_ROOT}/local_dependencies/godot-cpp" CACHE PATH "Path to local godot-cpp checkout")
set(PROTOCOL_BUILD_DIR "${PROJECT_ROOT}/native/protocol_client/build" CACHE PATH "Path to native protocol client build output")
set(GODOT_CPP_LIBRARY "${GODOT_CPP_DIR}/bin/libgodot-cpp.linux.template_debug.x86_64.a" CACHE FILEPATH "Path to built godot-cpp static library")

find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)

add_library(acore_godot_protocol SHARED
    src/acore_protocol_client.cpp
    src/register_types.cpp
)

target_include_directories(acore_godot_protocol SYSTEM PRIVATE
    "${GODOT_CPP_DIR}/include"
    "${GODOT_CPP_DIR}/gen/include"
    "${GODOT_CPP_DIR}/gdextension"
)

target_include_directories(acore_godot_protocol PRIVATE
    "${PROJECT_ROOT}/native/protocol_client/src"
)

target_link_libraries(acore_godot_protocol PRIVATE
    "${GODOT_CPP_LIBRARY}"
    "${PROTOCOL_BUILD_DIR}/libacore_protocol_core.a"
    OpenSSL::Crypto
    ZLIB::ZLIB
)

set_target_properties(acore_godot_protocol PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_ROOT}/bin"
    OUTPUT_NAME "acore_godot_protocol.linux.template_debug.x86_64"
    PREFIX "lib"
)

if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(acore_godot_protocol PRIVATE -Wall -Wextra)
endif()

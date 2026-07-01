cmake_minimum_required(VERSION 3.20)

project(acore_protocol_client LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)

add_library(acore_protocol_core STATIC
    src/arc4.cpp
    src/auth_crypt.cpp
    src/protocol_bytes.cpp
    src/protocol_flow.cpp
    src/srp6.cpp
    src/world_packets.cpp
)

set_target_properties(acore_protocol_core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(acore_protocol_core PUBLIC src)
target_link_libraries(acore_protocol_core PUBLIC OpenSSL::Crypto ZLIB::ZLIB)

add_executable(acore_protocol_client
    src/main.cpp
)
target_link_libraries(acore_protocol_client PRIVATE acore_protocol_core)

add_library(acore_protocol_bridge SHARED
    src/protocol_c_api.cpp
)
target_link_libraries(acore_protocol_bridge PRIVATE acore_protocol_core)

if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(acore_protocol_core PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(acore_protocol_client PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(acore_protocol_bridge PRIVATE -Wall -Wextra -Wpedantic)
endif()

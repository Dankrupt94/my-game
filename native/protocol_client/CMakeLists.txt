cmake_minimum_required(VERSION 3.20)

project(acore_protocol_client LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)

add_executable(acore_protocol_client
    src/arc4.cpp
    src/auth_crypt.cpp
    src/main.cpp
    src/protocol_bytes.cpp
    src/srp6.cpp
    src/world_packets.cpp
)

target_include_directories(acore_protocol_client PRIVATE src)
target_link_libraries(acore_protocol_client PRIVATE OpenSSL::Crypto ZLIB::ZLIB)

if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(acore_protocol_client PRIVATE -Wall -Wextra -Wpedantic)
endif()

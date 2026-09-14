cmake_minimum_required(VERSION 3.25)
project(OEPServerRepository LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

enable_testing()

# ---------------------------------------------------------------------------
# WP-SRV-011 -- the first Server Repository implementation (ADR-0006's
# authorized vertical slice). Dependency set and FetchContent mechanism
# mirror services/acquisition/CMakeLists.txt deliberately: this is a
# separate, standalone logical service (ADR-0005 SS5), not a shared build
# with EAM, but it reuses the exact same, already-proven toolchain
# (cpp-httplib, libpqxx, nlohmann/json, spdlog, tomlplusplus, Catch2)
# rather than introducing a second set of equivalent dependencies.
# ---------------------------------------------------------------------------
include(FetchContent)

set(SPDLOG_BUILD_SHARED OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
  spdlog
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG v1.15.0
  GIT_SHALLOW TRUE
)

FetchContent_Declare(
  nlohmann_json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG v3.11.3
  GIT_SHALLOW TRUE
)

FetchContent_Declare(
  tomlplusplus
  GIT_REPOSITORY https://github.com/marzer/tomlplusplus.git
  GIT_TAG v3.4.0
  GIT_SHALLOW TRUE
)

FetchContent_Declare(
  httplib
  GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
  GIT_TAG v0.18.5
  GIT_SHALLOW TRUE
)
set(HTTPLIB_REQUIRE_OPENSSL OFF CACHE BOOL "" FORCE)
set(HTTPLIB_REQUIRE_ZLIB OFF CACHE BOOL "" FORCE)
set(HTTPLIB_REQUIRE_BROTLI OFF CACHE BOOL "" FORCE)
set(HTTPLIB_COMPILE OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
  Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG v3.7.1
  GIT_SHALLOW TRUE
)

FetchContent_Declare(
  picosha2
  GIT_REPOSITORY https://github.com/okdshin/PicoSHA2.git
  GIT_TAG 161cb3fc4170fa7a3eca9e582cebd27cc4d1fe29
  GIT_SHALLOW TRUE
)

find_package(PostgreSQL REQUIRED)

set(SKIP_BUILD_TEST ON CACHE BOOL "" FORCE)
set(PQXX_SKIP_TESTS ON CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
  libpqxx
  GIT_REPOSITORY https://github.com/jtv/libpqxx.git
  GIT_TAG 7.9.2
  GIT_SHALLOW TRUE
)

FetchContent_MakeAvailable(spdlog nlohmann_json tomlplusplus httplib Catch2 libpqxx picosha2)

list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)

add_subdirectory(src/common)
add_subdirectory(src/domain)
add_subdirectory(src/persistence)
add_subdirectory(src/api)
add_subdirectory(src/app)
add_subdirectory(tests)

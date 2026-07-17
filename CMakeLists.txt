cmake_minimum_required(VERSION 3.25)
project(OEPAcquisition LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

enable_testing()

# ---------------------------------------------------------------------------
# Third-party dependencies (WORK_PACKAGE_001, per PROJECT_CONTEXT.md's
# declared stack: spdlog, TOML, nlohmann/json, Catch2). Fetched via CMake's
# own FetchContent -- no separate package manager (vcpkg/Conan) is installed
# in this environment, and FetchContent keeps the bootstrap self-contained
# with only CMake + a C++ compiler + network access required.
#
# PostgreSQL connectivity uses the raw `libpq` C client, located via CMake's
# built-in FindPostgreSQL module against the system PostgreSQL 18 install,
# wrapped by a small RAII class in src/database -- not the heavier libpqxx
# library, since WORK_PACKAGE_001 asks only for "connection management...
# connection only," not query execution with rich C++ type conversions.
# See README.md "Implementation Decisions".
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

FetchContent_MakeAvailable(spdlog nlohmann_json tomlplusplus httplib Catch2)

# Catch2's CTest integration (catch_discover_tests) lives in a CMake module
# shipped alongside Catch2's own sources, not on CMake's default module path.
list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)

find_package(PostgreSQL REQUIRED)

add_subdirectory(src/common)
add_subdirectory(src/database)
add_subdirectory(src/api)
add_subdirectory(src/app)
add_subdirectory(tests)

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
# PostgreSQL connectivity: WORK_PACKAGE_001 used the raw `libpq` C client
# directly (connection management only, no queries). WORK_PACKAGE_002 adds
# the first real Repository layer (parameterized CRUD + filtering), which is
# exactly the reassessment point WORK_PACKAGE_001's README flagged under
# "Future Considerations" -- `libpqxx` is now fetched alongside raw `libpq`
# so the Repository layer gets safe parameter binding, RAII transactions,
# and typed field access instead of hand-rolled C-string query building.
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

# WORK_PACKAGE_007 (Integrity Verification Engine) needs SHA-256 hash
# generation. PicoSHA2 is a single-header, MIT-licensed, dependency-free
# implementation -- avoids hand-rolling cryptographic code (Engineering
# Principle 6, Security by Design) while staying far lighter than pulling in
# all of OpenSSL for one hash algorithm (this project's cpp-httplib fetch
# above already deliberately disables OpenSSL to keep the build simple; see
# README.md "Implementation Decisions"). PicoSHA2 has no version tags, so it
# is pinned to a specific commit rather than a tag, same as any other
# untagged dependency would be.
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

# Catch2's CTest integration (catch_discover_tests) lives in a CMake module
# shipped alongside Catch2's own sources, not on CMake's default module path.
list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)

add_subdirectory(src/common)
add_subdirectory(src/database)
add_subdirectory(src/registry)
add_subdirectory(src/acquisition)
add_subdirectory(src/connectors)
add_subdirectory(src/downloads)
add_subdirectory(src/integrity)
add_subdirectory(src/metadata)
add_subdirectory(src/vault)
add_subdirectory(src/api)
add_subdirectory(src/app)
add_subdirectory(tests)

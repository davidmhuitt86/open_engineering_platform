add_library(oep_server_repository_common STATIC
  config.cpp
  logger.cpp
  uuid.cpp
  time.cpp
)

target_include_directories(oep_server_repository_common
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_server_repository_common
  PUBLIC
    spdlog::spdlog
    tomlplusplus::tomlplusplus
)

target_compile_features(oep_server_repository_common PUBLIC cxx_std_23)

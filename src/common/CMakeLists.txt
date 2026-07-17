add_library(oep_acquisition_common STATIC
  config.cpp
  logger.cpp
  uuid.cpp
)

target_include_directories(oep_acquisition_common
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_common
  PUBLIC
    spdlog::spdlog
    tomlplusplus::tomlplusplus
)

target_compile_features(oep_acquisition_common PUBLIC cxx_std_23)

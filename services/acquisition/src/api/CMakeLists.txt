add_library(oep_acquisition_api STATIC
  server.cpp
)

target_include_directories(oep_acquisition_api
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_api
  PUBLIC
    oep_acquisition_common
    oep_acquisition_registry
    oep_acquisition_jobs
    oep_acquisition_connectors
    oep_acquisition_downloads
    oep_acquisition_integrity
    oep_acquisition_metadata
    oep_acquisition_vault
  PRIVATE
    httplib::httplib
    nlohmann_json::nlohmann_json
)

target_compile_features(oep_acquisition_api PUBLIC cxx_std_23)

find_package(Threads REQUIRED)
target_link_libraries(oep_acquisition_api PRIVATE Threads::Threads)

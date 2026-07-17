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
  PRIVATE
    httplib::httplib
    nlohmann_json::nlohmann_json
)

target_compile_features(oep_acquisition_api PUBLIC cxx_std_23)

find_package(Threads REQUIRED)
target_link_libraries(oep_acquisition_api PRIVATE Threads::Threads)

add_library(oep_acquisition_connectors STATIC
  connector.cpp
  connector_json.cpp
  stub_connector.cpp
  http_connector.cpp
  connector_factory.cpp
  connector_registry.cpp
)

target_include_directories(oep_acquisition_connectors
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_connectors
  PUBLIC
    oep_acquisition_common
    nlohmann_json::nlohmann_json
  PRIVATE
    httplib::httplib
)

target_compile_features(oep_acquisition_connectors PUBLIC cxx_std_23)

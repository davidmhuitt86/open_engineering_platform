add_executable(oep_acquisition_tests
  test_smoke.cpp
  test_config.cpp
  test_database_connection.cpp
  test_server.cpp
)

target_link_libraries(oep_acquisition_tests
  PRIVATE
    oep_acquisition_common
    oep_acquisition_database
    oep_acquisition_api
    Catch2::Catch2WithMain
    httplib::httplib
    nlohmann_json::nlohmann_json
)

target_compile_features(oep_acquisition_tests PRIVATE cxx_std_23)

include(CTest)
include(Catch)
catch_discover_tests(oep_acquisition_tests)

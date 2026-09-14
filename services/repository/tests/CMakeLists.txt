add_executable(oep_server_repository_tests
  test_support.cpp
  test_server.cpp
  test_repository.cpp
  test_commit.cpp
  test_concurrency.cpp
  test_uuid_validation.cpp
  test_tombstone.cpp
)

target_link_libraries(oep_server_repository_tests
  PRIVATE
    oep_server_repository_common
    oep_server_repository_domain
    oep_server_repository_persistence
    oep_server_repository_api
    Catch2::Catch2WithMain
    httplib::httplib
    nlohmann_json::nlohmann_json
    libpqxx::pqxx
)

target_compile_features(oep_server_repository_tests PRIVATE cxx_std_23)

# Lets test_support.cpp apply migrations/V1__initial_schema.sql verbatim
# from disk, mirroring services/acquisition's own established convention
# exactly (registry_test_support.cpp / OEP_ACQUISITION_MIGRATIONS_DIR).
target_compile_definitions(oep_server_repository_tests
  PRIVATE
    "OEP_SERVER_REPOSITORY_MIGRATIONS_DIR=\"${CMAKE_SOURCE_DIR}/migrations\""
)

include(CTest)
include(Catch)
catch_discover_tests(oep_server_repository_tests)

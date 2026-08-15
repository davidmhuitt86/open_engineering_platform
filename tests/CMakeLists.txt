add_executable(oep_acquisition_tests
  test_smoke.cpp
  test_config.cpp
  test_database_connection.cpp
  test_server.cpp
  registry_test_support.cpp
  test_official_source_validation.cpp
  test_official_source_service.cpp
  test_official_source_repository.cpp
  test_official_source_migration.cpp
  test_official_source_api.cpp
  jobs_test_support.cpp
  test_acquisition_job_validation.cpp
  test_acquisition_job_service.cpp
  test_acquisition_job_repository.cpp
  test_acquisition_job_migration.cpp
  test_acquisition_job_api.cpp
  execution_test_support.cpp
  test_acquisition_execution_transitions.cpp
  test_acquisition_execution_service.cpp
  test_job_execution_history_repository.cpp
  test_acquisition_execution_api.cpp
  test_connector_factory.cpp
  test_connector_registry.cpp
  test_stub_connector.cpp
  test_http_connector.cpp
  test_connector_api.cpp
  downloads_test_support.cpp
  test_download_validation.cpp
  test_download_progress.cpp
  test_download_service.cpp
  test_download_repository.cpp
  test_download_migration.cpp
  test_download_api.cpp
  integrity_test_support.cpp
  test_hashing.cpp
  test_verification_validation.cpp
  test_verification_service.cpp
  test_verification_repository.cpp
  test_verification_migration.cpp
  test_verification_api.cpp
  metadata_test_support.cpp
  test_metadata_validation.cpp
  test_file_type_detector.cpp
  test_document_inspector.cpp
  test_metadata_extraction_service.cpp
  test_metadata_repository.cpp
  test_metadata_migration.cpp
  test_metadata_api.cpp
  vault_test_support.cpp
  test_vault_validation.cpp
  test_vault_path.cpp
  test_reference_vault_service.cpp
  test_vault_repository.cpp
  test_vault_migration.cpp
  test_vault_api.cpp
)

target_link_libraries(oep_acquisition_tests
  PRIVATE
    oep_acquisition_common
    oep_acquisition_database
    oep_acquisition_registry
    oep_acquisition_jobs
    oep_acquisition_connectors
    oep_acquisition_downloads
    oep_acquisition_integrity
    oep_acquisition_metadata
    oep_acquisition_vault
    oep_acquisition_api
    Catch2::Catch2WithMain
    httplib::httplib
    nlohmann_json::nlohmann_json
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_tests PRIVATE cxx_std_23)

# Lets registry_test_support.cpp apply migrations/V1__initial_schema.sql and
# migrations/V2__official_sources.sql verbatim from disk, so Repository/API/
# migration tests exercise the real, committed migration files rather than a
# hand-copied duplicate of their DDL.
target_compile_definitions(oep_acquisition_tests
  PRIVATE
    "OEP_ACQUISITION_MIGRATIONS_DIR=\"${CMAKE_SOURCE_DIR}/migrations\""
)

include(CTest)
include(Catch)
catch_discover_tests(oep_acquisition_tests)

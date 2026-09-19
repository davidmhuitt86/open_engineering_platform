add_library(oep_acquisition_provenance STATIC
  acquisition_record.cpp
  acquisition_record_json.cpp
  postgres_acquisition_record_repository.cpp
  acquisition_record_service.cpp
)

target_include_directories(oep_acquisition_provenance
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_provenance
  PUBLIC
    oep_acquisition_common
    oep_acquisition_registry
    oep_acquisition_jobs
    oep_acquisition_downloads
    oep_acquisition_integrity
    oep_acquisition_metadata
    oep_acquisition_vault
    nlohmann_json::nlohmann_json
  PRIVATE
    oep_acquisition_database
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_provenance PUBLIC cxx_std_23)

add_library(oep_acquisition_vault STATIC
  vault_entry.cpp
  vault_entry_json.cpp
  validation.cpp
  vault_path.cpp
  postgres_vault_repository.cpp
  reference_vault_service.cpp
)

target_include_directories(oep_acquisition_vault
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_vault
  PUBLIC
    oep_acquisition_common
    oep_acquisition_jobs
    oep_acquisition_downloads
    oep_acquisition_integrity
    oep_acquisition_metadata
    nlohmann_json::nlohmann_json
  PRIVATE
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_vault PUBLIC cxx_std_23)

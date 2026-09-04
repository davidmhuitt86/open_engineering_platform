add_library(oep_acquisition_metadata STATIC
  artifact_metadata.cpp
  artifact_metadata_json.cpp
  validation.cpp
  file_type_detector.cpp
  document_inspector.cpp
  postgres_metadata_repository.cpp
  metadata_extraction_service.cpp
)

target_include_directories(oep_acquisition_metadata
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_metadata
  PUBLIC
    oep_acquisition_common
    oep_acquisition_downloads
    oep_acquisition_integrity
    nlohmann_json::nlohmann_json
  PRIVATE
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_metadata PUBLIC cxx_std_23)

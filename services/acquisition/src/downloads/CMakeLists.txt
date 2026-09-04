add_library(oep_acquisition_downloads STATIC
  download.cpp
  download_json.cpp
  validation.cpp
  download_service.cpp
  postgres_download_repository.cpp
)

target_include_directories(oep_acquisition_downloads
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_downloads
  PUBLIC
    oep_acquisition_common
    oep_acquisition_jobs
    oep_acquisition_connectors
    nlohmann_json::nlohmann_json
  PRIVATE
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_downloads PUBLIC cxx_std_23)

add_library(oep_acquisition_registry STATIC
  official_source.cpp
  official_source_json.cpp
  validation.cpp
  official_source_service.cpp
  postgres_official_source_repository.cpp
)

target_include_directories(oep_acquisition_registry
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_registry
  PUBLIC
    oep_acquisition_common
    nlohmann_json::nlohmann_json
  PRIVATE
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_registry PUBLIC cxx_std_23)

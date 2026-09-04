add_library(oep_acquisition_integrity STATIC
  verification.cpp
  verification_json.cpp
  validation.cpp
  hashing.cpp
  postgres_verification_repository.cpp
  integrity_verification_service.cpp
)

target_include_directories(oep_acquisition_integrity
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_integrity
  PUBLIC
    oep_acquisition_common
    oep_acquisition_downloads
    nlohmann_json::nlohmann_json
  PRIVATE
    libpqxx::pqxx
    picosha2
)

target_compile_features(oep_acquisition_integrity PUBLIC cxx_std_23)

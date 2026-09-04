add_library(oep_acquisition_database STATIC
  database_connection.cpp
)

target_include_directories(oep_acquisition_database
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_database
  PUBLIC
    oep_acquisition_common
  PRIVATE
    PostgreSQL::PostgreSQL
)

target_compile_features(oep_acquisition_database PUBLIC cxx_std_23)

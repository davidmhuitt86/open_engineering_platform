add_library(oep_server_repository_persistence STATIC
  store.cpp
)

target_include_directories(oep_server_repository_persistence
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_server_repository_persistence
  PUBLIC
    oep_server_repository_common
    oep_server_repository_domain
  PRIVATE
    libpqxx::pqxx
    picosha2
)

target_compile_features(oep_server_repository_persistence PUBLIC cxx_std_23)

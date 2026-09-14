add_library(oep_server_repository_api STATIC
  auth.cpp
  server.cpp
)

target_include_directories(oep_server_repository_api
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_server_repository_api
  PUBLIC
    oep_server_repository_common
    oep_server_repository_domain
    oep_server_repository_persistence
  PRIVATE
    httplib::httplib
    nlohmann_json::nlohmann_json
    libpqxx::pqxx
)

target_compile_features(oep_server_repository_api PUBLIC cxx_std_23)

find_package(Threads REQUIRED)
target_link_libraries(oep_server_repository_api PRIVATE Threads::Threads)

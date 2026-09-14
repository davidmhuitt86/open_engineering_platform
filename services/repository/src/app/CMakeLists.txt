add_executable(oep_server_repository
  main.cpp
)

target_link_libraries(oep_server_repository
  PRIVATE
    oep_server_repository_common
    oep_server_repository_domain
    oep_server_repository_persistence
    oep_server_repository_api
)

target_compile_features(oep_server_repository PRIVATE cxx_std_23)

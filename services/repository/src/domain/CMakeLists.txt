add_library(oep_server_repository_domain STATIC
  types.cpp
)

target_include_directories(oep_server_repository_domain
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_compile_features(oep_server_repository_domain PUBLIC cxx_std_23)

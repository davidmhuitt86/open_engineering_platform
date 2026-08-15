cmake_minimum_required(VERSION 3.25)

add_library(oep_packages STATIC
    src/package_manifest.cpp
    src/package_manager.cpp
)

target_include_directories(oep_packages PUBLIC include)
target_compile_features(oep_packages PUBLIC cxx_std_23)
target_link_libraries(oep_packages PUBLIC oep_repository)

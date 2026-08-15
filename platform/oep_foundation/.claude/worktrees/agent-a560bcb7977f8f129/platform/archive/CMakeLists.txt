cmake_minimum_required(VERSION 3.25)

add_library(oep_archive STATIC
    src/export_manifest.cpp
    src/archive_codec.cpp
    src/repository_exporter.cpp
    src/repository_importer.cpp
    src/template_manifest.cpp
    src/repository_template.cpp
)

target_include_directories(oep_archive PUBLIC include)
target_compile_features(oep_archive PUBLIC cxx_std_23)
target_link_libraries(oep_archive PUBLIC oep_repository oep_packages)

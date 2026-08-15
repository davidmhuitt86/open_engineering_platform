cmake_minimum_required(VERSION 3.25)

add_library(oep_installer STATIC
    src/zip_reader.cpp
    src/oep_package_manifest.cpp
    src/sha256.cpp
    src/sha512.cpp
    src/ed25519.cpp
    src/trust_store.cpp
    src/package_verifier.cpp
    src/repository_registry.cpp
    src/package_installer.cpp
)

target_include_directories(oep_installer PUBLIC include)
target_compile_features(oep_installer PUBLIC cxx_std_23)
target_link_libraries(oep_installer PUBLIC oep_repository)

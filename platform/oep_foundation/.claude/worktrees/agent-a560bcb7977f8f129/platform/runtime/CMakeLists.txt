cmake_minimum_required(VERSION 3.25)

add_library(oep_runtime STATIC
    src/foundation_runtime.cpp
    src/transaction_journal.cpp
)

target_include_directories(oep_runtime PUBLIC include)
target_compile_features(oep_runtime PUBLIC cxx_std_23)
target_link_libraries(oep_runtime PUBLIC oep_repository oep_search oep_validation oep_packages oep_archive oep_installer)

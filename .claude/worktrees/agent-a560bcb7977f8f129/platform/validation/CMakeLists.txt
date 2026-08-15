cmake_minimum_required(VERSION 3.25)

add_library(oep_validation STATIC
    src/validation_result.cpp
    src/repository_validator.cpp
)

target_include_directories(oep_validation PUBLIC include)
target_compile_features(oep_validation PUBLIC cxx_std_23)
target_link_libraries(oep_validation PUBLIC oep_repository)

cmake_minimum_required(VERSION 3.25)

add_library(oep_api STATIC
    src/oep_api.cpp
)

target_include_directories(oep_api PUBLIC include)
target_include_directories(oep_api PRIVATE src)
target_compile_features(oep_api PUBLIC cxx_std_23)
target_link_libraries(oep_api PRIVATE oep_runtime)

add_subdirectory(manual_test)

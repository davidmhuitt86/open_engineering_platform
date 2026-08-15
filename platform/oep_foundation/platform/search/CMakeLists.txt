cmake_minimum_required(VERSION 3.25)

add_library(oep_search STATIC
    src/search_engine.cpp
)

target_include_directories(oep_search PUBLIC include)
target_compile_features(oep_search PUBLIC cxx_std_23)
target_link_libraries(oep_search PUBLIC oep_repository)

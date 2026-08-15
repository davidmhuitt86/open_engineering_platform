cmake_minimum_required(VERSION 3.25)

add_library(oep_repository STATIC
    src/metadata.cpp
    src/json_value.cpp
    src/uuid.cpp
    src/timestamp.cpp
    src/engineering_object.cpp
    src/object_store.cpp
    src/relationship.cpp
    src/relationship_store.cpp
    src/graph_engine.cpp
    src/audit_event.cpp
    src/audit_store.cpp
    src/batch_processor.cpp
)

target_include_directories(oep_repository PUBLIC include)
target_compile_features(oep_repository PUBLIC cxx_std_23)

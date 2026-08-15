cmake_minimum_required(VERSION 3.25)

add_library(oep_engine STATIC
    src/runtime_graph.cpp
    src/object_loader.cpp
    src/relationship_engine.cpp
    src/query_engine.cpp
    src/traversal_engine.cpp
    src/engineering_context.cpp
    src/knowledge_graph.cpp
    src/graph_validator.cpp
    src/graph_algorithms.cpp
    src/graph_statistics.cpp
    src/graph_serialization.cpp
    src/knowledge_graph_engine.cpp
    src/query_types.cpp
    src/query_planner.cpp
    src/query_executor.cpp
    src/query_cache.cpp
    src/engineering_query_engine.cpp
    src/rule_types.cpp
    src/rule_registry.cpp
    src/rule_evaluator.cpp
    src/rules_engine.cpp
    src/validation_types.cpp
    src/validation_engine.cpp
    src/analysis_engine.cpp
    src/reasoning_types.cpp
    src/reasoning_engine.cpp
    src/intelligence_types.cpp
    src/knowledge_session_manager.cpp
    src/engineering_intelligence_platform.cpp
)

target_include_directories(oep_engine PUBLIC include)
target_compile_features(oep_engine PUBLIC cxx_std_23)
target_link_libraries(oep_engine PUBLIC oep_runtime)

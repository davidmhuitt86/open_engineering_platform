cmake_minimum_required(VERSION 3.25)

add_library(oep_cli_core STATIC
    src/command_registry.cpp
    src/commands/batch_command.cpp
    src/commands/export_command.cpp
    src/commands/graph_command.cpp
    src/commands/help_command.cpp
    src/commands/import_command.cpp
    src/commands/init_command.cpp
    src/commands/object_command.cpp
    src/commands/open_command.cpp
    src/commands/package_command.cpp
    src/commands/transaction_command.cpp
    src/commands/trust_command.cpp
    src/commands/packages_command.cpp
    src/commands/relationship_command.cpp
    src/commands/repository_path_option.cpp
    src/commands/search_command.cpp
    src/commands/status_command.cpp
    src/commands/template_command.cpp
    src/commands/validate_command.cpp
    src/commands/version_command.cpp
    src/generator/repository_generator.cpp
)

target_include_directories(oep_cli_core PUBLIC include src)
target_compile_features(oep_cli_core PUBLIC cxx_std_23)
target_link_libraries(oep_cli_core PUBLIC oep_repository oep_runtime oep_search oep_validation oep_packages)

add_executable(oep src/main.cpp)
target_link_libraries(oep PRIVATE oep_cli_core)

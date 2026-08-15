#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace oep::cli::commands {

// Pulls `<flag_name> <value>` out of `args` if present (anywhere),
// returning the value (defaulting to the current working directory
// if absent) and leaving the remaining arguments in `args`. General
// primitive behind extract_repository_path and any other command
// option that names a filesystem path, so a value-bearing flag can't
// collide with a subcommand's positional arguments.
std::filesystem::path extract_path_option(std::vector<std::string>& args, const std::string& flag_name);

// Pulls a bare boolean flag (no value) out of `args` if present,
// returning whether it was found and removing it from `args`.
bool extract_flag(std::vector<std::string>& args, const std::string& flag_name);

// Pulls `--repository <path>` out of `args` if present (anywhere),
// returning the repository path (defaulting to the current working
// directory) and leaving the remaining arguments in `args`. Shared by
// every command whose subcommands take a positional ID, so
// `--repository` can't collide with that positional slot.
std::filesystem::path extract_repository_path(std::vector<std::string>& args);

// Splits a comma-separated flag value (e.g. `--tags a,b,c`) into its
// individual, non-empty entries. Shared by every command that accepts
// a comma-separated list flag.
std::vector<std::string> split_csv(const std::string& csv);

} // namespace oep::cli::commands

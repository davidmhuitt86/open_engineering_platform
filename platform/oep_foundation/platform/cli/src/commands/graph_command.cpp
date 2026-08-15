#include "graph_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Pulls `--algorithm <bfs|dfs>` out of `args` if present, defaulting to
// "bfs" when absent. Only `traverse` uses this; `neighbors`/`path`
// tolerate and ignore it if given.
std::string extract_algorithm(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--algorithm" && i + 1 < args.size()) {
            std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i),
                       args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            return value;
        }
    }
    return "bfs";
}

void print_object_row(const oep::runtime::FoundationRuntime& runtime, const std::string& object_id) {
    const oep::repository::LoadObjectResult loaded = runtime.object_store()->load(object_id);
    std::cout << object_id;
    if (loaded.success) {
        std::cout << "\t" << oep::repository::to_string(loaded.object.object_type) << "\t" << loaded.object.name;
    }
}

} // namespace

std::string GraphCommand::name() const {
    return "graph";
}

std::string GraphCommand::description() const {
    return "Explore Engineering Objects through their Relationships";
}

int GraphCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'graph' requires a subcommand (neighbors, traverse, path)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "neighbors") return neighbors(rest);
    if (subcommand == "traverse") return traverse(rest);
    if (subcommand == "path") return path(rest);

    std::cerr << "oep: unknown 'graph' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int GraphCommand::neighbors(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    extract_algorithm(remaining); // not used by neighbors; tolerated if given

    if (remaining.empty()) {
        std::cerr << "oep: 'graph neighbors' requires an object ID\n";
        std::cerr << "Usage: oep graph neighbors <object-id> [--repository <path>]\n";
        return 1;
    }
    const std::string& object_id = remaining[0];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::NeighborsResult result = runtime.graph_engine()->get_neighbors(object_id);
    if (!result.success) {
        std::cerr << "oep: could not get neighbors: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Neighbors:\n";
    if (result.neighbors.empty()) {
        std::cout << "  No neighbors found.\n";
    } else {
        for (const oep::repository::GraphNeighbor& neighbor : result.neighbors) {
            const oep::repository::LoadObjectResult loaded = runtime.object_store()->load(neighbor.object_id);
            if (!loaded.success) continue;
            std::cout << "  " << neighbor.object_id << "\t" << oep::repository::to_string(loaded.object.object_type)
                       << "\t" << loaded.object.name << "\t"
                       << oep::repository::to_string(neighbor.relationship_type) << "\n";
        }
    }

    runtime.shutdown();
    return 0;
}

int GraphCommand::traverse(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::string algorithm = extract_algorithm(remaining);

    if (algorithm != "bfs" && algorithm != "dfs") {
        std::cerr << "oep: unrecognized --algorithm '" << algorithm << "' (expected 'bfs' or 'dfs')\n";
        return 1;
    }

    if (remaining.empty()) {
        std::cerr << "oep: 'graph traverse' requires an object ID\n";
        std::cerr << "Usage: oep graph traverse <object-id> [--algorithm bfs|dfs] [--repository <path>]\n";
        return 1;
    }
    const std::string& start_object_id = remaining[0];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::TraversalResult result = (algorithm == "dfs")
                                                          ? runtime.graph_engine()->traverse_depth_first(start_object_id)
                                                          : runtime.graph_engine()->traverse_breadth_first(start_object_id);
    if (!result.success) {
        std::cerr << "oep: could not traverse graph: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Traversal (" << (algorithm == "dfs" ? "DFS" : "BFS") << "):\n";
    for (std::size_t i = 0; i < result.object_ids.size(); ++i) {
        std::cout << "  " << (i + 1) << "\t";
        print_object_row(runtime, result.object_ids[i]);
        std::cout << "\n";
    }

    runtime.shutdown();
    return 0;
}

int GraphCommand::path(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    extract_algorithm(remaining); // not used by path; tolerated if given

    if (remaining.size() < 2) {
        std::cerr << "oep: 'graph path' requires a source and target object ID\n";
        std::cerr << "Usage: oep graph path <source-object-id> <target-object-id> [--repository <path>]\n";
        return 1;
    }
    const std::string& source_object_id = remaining[0];
    const std::string& target_object_id = remaining[1];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::PathExistsResult result =
        runtime.graph_engine()->path_exists(source_object_id, target_object_id);
    if (!result.success) {
        std::cerr << "oep: could not determine path: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << (result.path_exists ? "Path Found\n" : "No Path Found\n");

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands

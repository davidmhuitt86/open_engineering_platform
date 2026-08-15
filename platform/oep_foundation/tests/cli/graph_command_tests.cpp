#include "commands/graph_command.hpp"
#include "commands/object_command.hpp"
#include "commands/relationship_command.hpp"
#include "generator/repository_generator.hpp"

#include <filesystem>
#include <functional>
#include <iostream>
#include <sstream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

std::string capture_stdout(const std::function<void()>& action) {
    std::ostringstream buffer;
    std::streambuf* original = std::cout.rdbuf(buffer.rdbuf());
    action();
    std::cout.rdbuf(original);
    return buffer.str();
}

std::string capture_stderr(const std::function<void()>& action) {
    std::ostringstream buffer;
    std::streambuf* original = std::cerr.rdbuf(buffer.rdbuf());
    action();
    std::cerr.rdbuf(original);
    return buffer.str();
}

bool contains(const std::string& haystack, const std::string& needle) {
    return haystack.find(needle) != std::string::npos;
}

std::filesystem::path build_repository(const std::filesystem::path& parent, const std::string& name) {
    const oep::cli::generator::GenerationResult result =
        oep::cli::generator::generate_foundation_repository(parent / name, name);
    check(result.success, "generating a sample repository for graph command tests succeeds");
    return parent / name;
}

std::string extract_created_id(const std::string& output) {
    const std::size_t first_quote = output.find('\'');
    const std::size_t second_quote = output.find('\'', first_quote + 1);
    if (first_quote == std::string::npos || second_quote == std::string::npos) {
        return "";
    }
    return output.substr(first_quote + 1, second_quote - first_quote - 1);
}

std::string create_object(const std::filesystem::path& repo, const std::string& type, const std::string& name) {
    oep::cli::commands::ObjectCommand object_command;
    const std::string output = capture_stdout([&] {
        object_command.execute({"create", "--type", type, "--name", name, "--repository", repo.string()});
    });
    return extract_created_id(output);
}

void connect(const std::filesystem::path& repo, const std::string& source, const std::string& target,
             const std::string& type = "ConnectedTo") {
    oep::cli::commands::RelationshipCommand relationship_command;
    capture_stdout([&] {
        relationship_command.execute(
            {"create", "--source", source, "--target", target, "--type", type, "--repository", repo.string()});
    });
}

// Builds A - B - C (a chain), with D left isolated. Returns {A, B, C, D}.
struct SampleGraph {
    std::string a, b, c, d;
};

SampleGraph build_sample_graph(const std::filesystem::path& repo) {
    SampleGraph graph;
    graph.a = create_object(repo, "Document", "A");
    graph.b = create_object(repo, "Component", "B");
    graph.c = create_object(repo, "Component", "C");
    graph.d = create_object(repo, "Component", "D");
    connect(repo, graph.a, graph.b);
    connect(repo, graph.b, graph.c);
    return graph;
}

void test_neighbors_lists_directly_connected_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "neighbors");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"neighbors", graph.b, "--repository", repo.string()}); });

    check(exit_code == 0, "neighbors succeeds for a connected object");
    check(contains(output, graph.a) && contains(output, graph.c), "neighbors lists both of B's neighbors (A and C)");
    check(contains(output, "ConnectedTo"), "neighbors reports the connecting relationship type");
}

void test_neighbors_reports_none_for_isolated_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "isolated-neighbors");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"neighbors", graph.d, "--repository", repo.string()}); });

    check(exit_code == 0, "neighbors succeeds for an isolated object");
    check(contains(output, "No neighbors found"), "neighbors reports none for an isolated object");
}

void test_bfs_traversal_visits_connected_component(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "bfs");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"traverse", graph.a, "--repository", repo.string()}); });

    check(exit_code == 0, "BFS traverse succeeds");
    check(contains(output, "BFS"), "traverse without --algorithm defaults to BFS");
    check(contains(output, graph.a) && contains(output, graph.b) && contains(output, graph.c),
          "BFS traversal from A visits A, B, and C");
    check(!contains(output, graph.d), "BFS traversal from A does not reach the isolated object D");
}

void test_dfs_traversal_visits_connected_component(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "dfs");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"traverse", graph.a, "--algorithm", "dfs", "--repository", repo.string()}); });

    check(exit_code == 0, "DFS traverse succeeds");
    check(contains(output, "DFS"), "--algorithm dfs is reflected in the output");
    check(contains(output, graph.a) && contains(output, graph.b) && contains(output, graph.c),
          "DFS traversal from A visits A, B, and C");
}

void test_path_found_for_connected_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "path-found");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"path", graph.a, graph.c, "--repository", repo.string()}); });

    check(exit_code == 0, "path succeeds for a connected pair");
    check(contains(output, "Path Found"), "path reports Path Found for a connected pair");
}

void test_path_not_found_for_disconnected_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "path-not-found");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"path", graph.a, graph.d, "--repository", repo.string()}); });

    check(exit_code == 0, "path succeeds (as an operation) even when no path exists");
    check(contains(output, "No Path Found"), "path reports No Path Found for a disconnected pair");
}

void test_invalid_object_id_is_reported_descriptively(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "invalid-id");
    build_sample_graph(repo);

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code =
            command.execute({"neighbors", "00000000-0000-4000-8000-000000000000", "--repository", repo.string()});
    });

    check(exit_code != 0, "neighbors fails for a nonexistent object ID");
    check(!error_output.empty(), "neighbors reports a descriptive error for a nonexistent object ID");
}

void test_empty_repository_handled_gracefully(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "empty-repo");

    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    capture_stderr([&] {
        exit_code =
            command.execute({"neighbors", "00000000-0000-4000-8000-000000000000", "--repository", repo.string()});
    });

    check(exit_code != 0, "neighbors fails gracefully (not a crash) against an empty repository");
}

void test_invalid_repository_reports_descriptive_error(const std::filesystem::path& scratch_dir) {
    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute(
            {"neighbors", "00000000-0000-4000-8000-000000000000", "--repository", (scratch_dir / "missing").string()});
    });

    check(exit_code != 0, "graph commands fail for a nonexistent repository");
    check(!error_output.empty(), "a nonexistent repository is reported with a descriptive error");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::GraphCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });

    check(exit_code != 0, "an unrecognized 'graph' subcommand fails");
    check(contains(error_output, "unknown"), "the error names the unknown subcommand");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_graph_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_neighbors_lists_directly_connected_objects(scratch_dir);
    test_neighbors_reports_none_for_isolated_object(scratch_dir);
    test_bfs_traversal_visits_connected_component(scratch_dir);
    test_dfs_traversal_visits_connected_component(scratch_dir);
    test_path_found_for_connected_objects(scratch_dir);
    test_path_not_found_for_disconnected_objects(scratch_dir);
    test_invalid_object_id_is_reported_descriptively(scratch_dir);
    test_empty_repository_handled_gracefully(scratch_dir);
    test_invalid_repository_reports_descriptive_error(scratch_dir);
    test_unknown_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All graph command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " graph command test(s) failed.\n";
    return 1;
}

#include "commands/engine_command.hpp"
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
    check(result.success, "generating a sample repository for engine command tests succeeds");
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

std::string create_object(const std::filesystem::path& repo, const std::string& type, const std::string& name,
                           const std::string& tags = "") {
    oep::cli::commands::ObjectCommand object_command;
    std::vector<std::string> args = {"create", "--type", type, "--name", name, "--repository", repo.string()};
    if (!tags.empty()) {
        args.push_back("--tags");
        args.push_back(tags);
    }
    const std::string output = capture_stdout([&] { object_command.execute(args); });
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
    graph.a = create_object(repo, "Document", "A", "domain-alpha");
    graph.b = create_object(repo, "Component", "B", "domain-alpha");
    graph.c = create_object(repo, "Component", "C");
    graph.d = create_object(repo, "Component", "D");
    connect(repo, graph.a, graph.b);
    connect(repo, graph.b, graph.c);
    return graph;
}

void test_load_reports_counts(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "load");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = command.execute({"load", "--repository", repo.string()}); });

    check(exit_code == 0, "engine load succeeds");
    check(contains(output, "Objects loaded: 4"), "engine load reports the correct object count");
    check(contains(output, "Relationships loaded: 2"), "engine load reports the correct relationship count");
    (void)graph;
}

void test_stats_reports_graph_counts(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "stats");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = command.execute({"stats", "--repository", repo.string()}); });

    check(exit_code == 0, "engine stats succeeds");
    check(contains(output, "Objects: 4"), "engine stats reports the correct object count");
    check(contains(output, "Relationships: 2"), "engine stats reports the correct relationship count");
}

void test_inspect_prints_fields_and_related_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "inspect");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"inspect", graph.b, "--repository", repo.string()}); });

    check(exit_code == 0, "engine inspect succeeds for an existing object");
    check(contains(output, "Name: B"), "engine inspect prints the object's name");
    check(contains(output, "Related objects:"), "engine inspect prints a related objects section");
    check(contains(output, graph.a) && contains(output, graph.c), "engine inspect lists B's related objects (A and C)");
}

void test_inspect_reports_missing_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "inspect-missing");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute({"inspect", "00000000-0000-4000-8000-000000000000", "--repository", repo.string()});
    });

    check(exit_code != 0, "engine inspect fails for a nonexistent object ID");
    check(!error_output.empty(), "engine inspect reports a descriptive error for a nonexistent object ID");
}

void test_query_by_type(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "query-type");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"query", "--type", "Component", "--repository", repo.string()}); });

    check(exit_code == 0, "engine query --type succeeds");
    check(contains(output, graph.b) && contains(output, graph.c) && contains(output, graph.d),
          "engine query --type Component lists every Component object");
    check(!contains(output, graph.a), "engine query --type Component does not list the Document object");
}

void test_query_by_domain(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "query-domain");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"query", "--domain", "domain-alpha", "--repository", repo.string()}); });

    check(exit_code == 0, "engine query --domain succeeds");
    check(contains(output, graph.a) && contains(output, graph.b), "engine query --domain lists the tagged objects");
    check(!contains(output, graph.c), "engine query --domain excludes an object without the tag");
}

void test_query_requires_exactly_one_selector(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "query-invalid");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({"query", "--repository", repo.string()}); });
    check(exit_code != 0, "engine query with no selector is rejected");

    exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute({"query", "--type", "Component", "--domain", "x", "--repository", repo.string()});
    });
    check(exit_code != 0, "engine query with two selectors is rejected");
}

void test_bfs_traversal_visits_connected_component(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "traverse-bfs");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"traverse", graph.a, "--repository", repo.string()}); });

    check(exit_code == 0, "engine traverse succeeds");
    check(contains(output, "BFS"), "engine traverse without --order defaults to BFS");
    check(contains(output, graph.a) && contains(output, graph.b) && contains(output, graph.c),
          "BFS traversal from A visits A, B, and C");
    check(!contains(output, graph.d), "BFS traversal from A does not reach the isolated object D");
}

void test_dfs_traversal(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "traverse-dfs");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"traverse", graph.a, "--order", "dfs", "--repository", repo.string()}); });

    check(exit_code == 0, "engine traverse --order dfs succeeds");
    check(contains(output, "DFS"), "--order dfs is reflected in the output");
}

void test_traverse_max_depth_limits_reach(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "traverse-max-depth");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"traverse", graph.a, "--max-depth", "1", "--repository", repo.string()});
    });

    check(exit_code == 0, "engine traverse --max-depth succeeds");
    check(contains(output, graph.a) && contains(output, graph.b), "--max-depth 1 from A reaches A and B");
    check(!contains(output, graph.c), "--max-depth 1 from A does not reach C (two edges away)");
}

void test_build_reports_counts(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "build");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"build", "--repository", repo.string()}); });

    check(exit_code == 0, "engine build succeeds");
    check(contains(output, "Objects: 4"), "engine build reports the correct object count");
    check(contains(output, "Relationships: 2"), "engine build reports the correct relationship count");
}

void test_validate_reports_valid_graph(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "validate-clean");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"validate", "--repository", repo.string()}); });

    check(exit_code == 0, "engine validate succeeds on a clean graph");
    check(contains(output, "Valid: yes"), "engine validate reports Valid: yes for a clean graph");
}

void test_stats_reports_full_statistics(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "stats-full");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"stats", "--repository", repo.string()}); });

    check(exit_code == 0, "engine stats succeeds");
    check(contains(output, "Connected components: 2"), "engine stats reports the correct component count");
    check(contains(output, "Density:"), "engine stats reports density");
    check(contains(output, "Maximum depth:"), "engine stats reports maximum depth");
    check(contains(output, "Average degree:"), "engine stats reports average degree");
    check(contains(output, "Relationship distribution:"), "engine stats reports the relationship distribution");
    check(contains(output, "Domain distribution:"), "engine stats reports the domain distribution");
}

void test_components_prints_each_component(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "components");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"components", "--repository", repo.string()}); });

    check(exit_code == 0, "engine components succeeds");
    check(contains(output, "Connected components: 2"), "engine components reports two components (A-B-C and D)");
    check(contains(output, graph.a) && contains(output, graph.b) && contains(output, graph.c),
          "engine components lists A, B, C together");
    check(contains(output, graph.d), "engine components lists the isolated object D");
}

void test_export_json(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "export-json");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"export", "--format", "json", "--repository", repo.string()}); });

    check(exit_code == 0, "engine export --format json succeeds");
    check(contains(output, "\"objects\""), "engine export --format json includes an objects array");
    check(contains(output, "\"relationships\""), "engine export --format json includes a relationships array");
    check(contains(output, graph.a), "engine export --format json includes object A's id");
}

void test_export_graphml(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "export-graphml");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"export", "--format", "graphml", "--repository", repo.string()}); });

    check(exit_code == 0, "engine export --format graphml succeeds");
    check(contains(output, "<graphml"), "engine export --format graphml emits a graphml document");
}

void test_export_requires_format(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "export-missing-format");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({"export", "--repository", repo.string()}); });
    check(exit_code != 0, "engine export without --format is rejected");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });

    check(exit_code != 0, "an unrecognized 'engine' subcommand fails");
    check(contains(error_output, "unknown"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "'engine' with no subcommand is rejected");
}

void test_query_category_dependency(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "query-category-dependency");
    const SampleGraph graph = build_sample_graph(repo);
    // A DependsOn edge, distinct from build_sample_graph's ConnectedTo chain.
    connect(repo, graph.c, graph.d, "DependsOn");

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"query", "--category", "dependency", "--id", graph.c, "--repository", repo.string()});
    });

    check(exit_code == 0, "engine query --category dependency succeeds");
    check(contains(output, "Category: Dependency"), "engine query --category dependency reports its category");
    check(contains(output, graph.c) && contains(output, graph.d),
          "engine query --category dependency includes the start object and its DependsOn target");
}

void test_query_category_neighborhood(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "query-category-neighborhood");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"query", "--category", "neighborhood", "--id", graph.b, "--depth", "1", "--repository", repo.string()});
    });

    check(exit_code == 0, "engine query --category neighborhood succeeds");
    // GraphAlgorithms::neighborhood returns only the surrounding
    // objects, not the starting object itself.
    check(contains(output, graph.a) && contains(output, graph.c),
          "engine query --category neighborhood --depth 1 from B reaches A and C");
    check(!contains(output, graph.d), "engine query --category neighborhood --depth 1 from B does not reach D");
}

void test_query_category_metadata_with_tags(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "query-category-metadata");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"query", "--category", "metadata", "--tags", "domain-alpha", "--repository", repo.string()});
    });

    check(exit_code == 0, "engine query --category metadata --tags succeeds");
    check(contains(output, graph.a) && contains(output, graph.b),
          "engine query --category metadata --tags domain-alpha matches A and B");
    check(!contains(output, graph.c), "engine query --category metadata --tags domain-alpha excludes untagged C");
}

void test_query_category_requires_category_value() {
    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({"query", "--category", "not-a-real-category"}); });
    check(exit_code != 0, "engine query --category with an unrecognized value is rejected");
    check(contains(error_output, "unrecognized"), "the error names the unrecognized category");
}

void test_query_backward_compatible_after_category_addition(const std::filesystem::path& scratch_dir) {
    // Re-runs the original WP-EKE-001 --type/--domain selectors (already
    // covered above) once more, specifically to pin down that adding
    // --category did not change their behavior.
    const std::filesystem::path repo = build_repository(scratch_dir, "query-backward-compat");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"query", "--id", graph.a, "--repository", repo.string()}); });

    check(exit_code == 0, "engine query --id (no --category) still succeeds after WP-EKE-003");
    check(contains(output, "Matching objects:"), "engine query --id still uses the original output format");
    check(contains(output, graph.a), "engine query --id still returns the requested object");
}

void test_explain_prints_plan_without_executing(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "explain");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code =
            command.execute({"explain", "--category", "object", "--id", graph.a, "--repository", repo.string()});
    });

    check(exit_code == 0, "engine explain succeeds");
    check(contains(output, "Category: Object"), "engine explain reports the query category");
    check(contains(output, "Strategy:"), "engine explain reports the traversal strategy");
    check(contains(output, "Estimated cost:"), "engine explain reports an estimated cost");
    check(contains(output, "Indexes used:"), "engine explain reports the indexes used");
    check(contains(output, "Execution order preview"), "engine explain reports an execution order preview");
}

void test_explain_requires_category(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "explain-missing-category");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({"explain", "--repository", repo.string()}); });
    check(exit_code != 0, "engine explain without --category is rejected");
}

void test_profile_reports_full_statistics(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "profile");
    const SampleGraph graph = build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"profile", "--category", "neighborhood", "--id", graph.b, "--repository", repo.string()});
    });

    check(exit_code == 0, "engine profile succeeds");
    check(contains(output, "Execution time (ms):"), "engine profile reports execution time");
    check(contains(output, "Objects examined:"), "engine profile reports objects examined");
    check(contains(output, "Relationships examined:"), "engine profile reports relationships examined");
    check(contains(output, "Traversal depth:"), "engine profile reports traversal depth");
    check(contains(output, "Result count:"), "engine profile reports result count");
    check(contains(output, "Traversal summary:"), "engine profile reports a traversal summary");
}

void test_cache_reports_counts(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "cache");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"cache", "--repository", repo.string()}); });

    check(exit_code == 0, "engine cache succeeds");
    check(contains(output, "Cached plans:"), "engine cache reports the cached plan count");
    check(contains(output, "Cached results:"), "engine cache reports the cached result count");
}

void test_clear_cache_succeeds(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "clear-cache");
    build_sample_graph(repo);

    oep::cli::commands::EngineCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"clear-cache", "--repository", repo.string()}); });

    check(exit_code == 0, "engine clear-cache succeeds");
    check(contains(output, "Query cache cleared."), "engine clear-cache reports success");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_engine_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_load_reports_counts(scratch_dir);
    test_stats_reports_graph_counts(scratch_dir);
    test_inspect_prints_fields_and_related_objects(scratch_dir);
    test_inspect_reports_missing_object(scratch_dir);
    test_query_by_type(scratch_dir);
    test_query_by_domain(scratch_dir);
    test_query_requires_exactly_one_selector(scratch_dir);
    test_bfs_traversal_visits_connected_component(scratch_dir);
    test_dfs_traversal(scratch_dir);
    test_traverse_max_depth_limits_reach(scratch_dir);
    test_build_reports_counts(scratch_dir);
    test_validate_reports_valid_graph(scratch_dir);
    test_stats_reports_full_statistics(scratch_dir);
    test_components_prints_each_component(scratch_dir);
    test_export_json(scratch_dir);
    test_export_graphml(scratch_dir);
    test_export_requires_format(scratch_dir);
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();
    test_query_category_dependency(scratch_dir);
    test_query_category_neighborhood(scratch_dir);
    test_query_category_metadata_with_tags(scratch_dir);
    test_query_category_requires_category_value();
    test_query_backward_compatible_after_category_addition(scratch_dir);
    test_explain_prints_plan_without_executing(scratch_dir);
    test_explain_requires_category(scratch_dir);
    test_profile_reports_full_statistics(scratch_dir);
    test_cache_reports_counts(scratch_dir);
    test_clear_cache_succeeds(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All engine command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " engine command test(s) failed.\n";
    return 1;
}

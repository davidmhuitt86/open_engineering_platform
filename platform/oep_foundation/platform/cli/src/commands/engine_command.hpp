#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes the Engineering Knowledge Runtime (WP-EKE-001) -- Object
// Loader, Runtime Graph, and Relationship/Query/Traversal Engines,
// behind oep::engine::EngineeringContext -- as `oep engine <subcommand>`.
//
// Naming note: WP-016's pre-existing `oep graph` command
// (neighbors/traverse/path, see graph_command.hpp) already occupies the
// "graph" name for the Repository Graph Engine, a lower-level primitive
// that walks Relationships directly off FoundationRuntime. WP-EKE-001's
// Runtime Graph is a distinct concept (an in-memory index built from an
// Object Loader snapshot, with its own Query/Traversal engines and
// domain-by-tag queries), so this Work Package's CLI surface is added
// as a new top-level command, `oep engine`, rather than colliding with
// or repurposing `oep graph`. Every subcommand here is self-contained
// (as required for a fresh CLI invocation with no persistent engine
// state between commands): it opens the repository, calls
// EngineeringContext::load_graph() internally, then performs the
// requested operation, all within one process.
// WP-EKE-002 adds `build`, `validate`, `components`, and `export` to
// this same command group, and enhances `stats` to report the
// Knowledge Graph Engine's richer GraphStatistics (object/relationship/
// connected-component counts, density, maximum depth, average degree,
// and the relationship-type/domain distributions) rather than just the
// Runtime Graph's raw object/relationship counts. Each new subcommand
// is self-contained exactly like the WP-EKE-001 ones above: it opens
// the repository, builds the Knowledge Graph via
// KnowledgeGraphEngine::build_graph() internally, then performs the
// requested operation, all within one process.
//
// WP-EKE-003 adds `explain`, `cache`, `profile`, and `clear-cache` to
// this same command group, backed by EngineeringQueryEngine, and
// extends the EXISTING `query` subcommand rather than replacing it.
// Backward-compatibility decision: `query`'s original WP-EKE-001
// selectors (--id/--type/--domain/--relationship, exactly one required)
// keep working exactly as before, still answered by
// EngineeringContext::query() -- unchanged behavior, unchanged output.
// A NEW `--category <name>` flag opts into WP-EKE-003's ten-category
// Engineering Query Engine instead: when `--category` is given, the
// richer flags below become available (--secondary-id, --publisher,
// --package, --tags, --depth, --direction) and the original four
// selector flags are rejected together with `--category` (mixing the
// two selection styles in one invocation is refused with an error,
// rather than silently picking one). This keeps every existing script
// invoking `oep engine query --id ...`/`--type ...`/etc. unaffected,
// while giving WP-EKE-003's Dependency/Neighborhood/Path/Reference/
// Metadata/Composite categories a single, discoverable home instead of
// a differently-named sibling command. Each new subcommand is
// self-contained exactly like the WP-EKE-001/WP-EKE-002 ones above: it
// opens the repository, builds the Knowledge Graph, and (since queries
// need it) constructs an EngineeringQueryEngine over it internally,
// then performs the requested operation, all within one process.
class EngineCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep engine <load|stats|inspect|query|traverse|build|validate|components|export|explain|cache|"
               "profile|clear-cache> [args...] [--repository <path>]";
    }

private:
    int load(const std::vector<std::string>& args) const;
    int stats(const std::vector<std::string>& args) const;
    int inspect(const std::vector<std::string>& args) const;
    int query(const std::vector<std::string>& args) const;
    int traverse(const std::vector<std::string>& args) const;
    int build(const std::vector<std::string>& args) const;
    int validate(const std::vector<std::string>& args) const;
    int components(const std::vector<std::string>& args) const;
    int export_graph(const std::vector<std::string>& args) const;
    int explain(const std::vector<std::string>& args) const;
    int cache(const std::vector<std::string>& args) const;
    int profile(const std::vector<std::string>& args) const;
    int clear_cache(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands

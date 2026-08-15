#include "engine_command.hpp"

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>
#include <sstream>

#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/graph_serialization.hpp"
#include "oep/engine/graph_statistics.hpp"
#include "oep/engine/graph_validator.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/query_types.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Opens `repository_path` and loads the Runtime Graph in one step --
// every subcommand below needs both, and a fresh CLI invocation has no
// persistent engine state to reuse from a prior `oep engine load` call.
// Returns nullopt (having already printed a descriptive error) on
// failure.
// `kge`, constructed from `context` (never from `service`/`runtime`
// directly), preserves the same "consume only the layer directly
// beneath you" boundary WP-EKE-002's KnowledgeGraphEngine requires.
// Its graph is only ever built on demand (see open_and_build_kge below)
// -- the WP-EKE-001 subcommands above never touch it.
// `eqe`, constructed from `kge` (never from `context`/`service`/
// `runtime` directly), is WP-EKE-003's Engineering Query Engine -- used
// only by query (--category mode)/explain/cache/profile/clear-cache.
struct OpenedEngine {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;

    explicit OpenedEngine(const std::string& foundation_version)
        : runtime(foundation_version), service(oep::runtime::RuntimeContext(runtime, events)), context(service),
          kge(context), eqe(kge) {}
};

std::unique_ptr<OpenedEngine> open_and_load(const std::filesystem::path& repository_path) {
    auto engine = std::make_unique<OpenedEngine>(kFoundationVersion);
    engine->runtime.initialize();

    const oep::runtime::RuntimeResult opened = engine->runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    const oep::engine::EngineeringContext::LoadGraphResult loaded = engine->context.load_graph();
    if (!loaded.success) {
        std::cerr << "oep: could not load the Runtime Graph: " << loaded.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    return engine;
}

// Opens `repository_path` and builds the Knowledge Graph in one step --
// used by the WP-EKE-002 subcommands (build/validate/stats/components/
// export) below, which need the Knowledge Graph Engine rather than the
// WP-EKE-001 Runtime Graph. Returns nullopt (having already printed a
// descriptive error) on failure.
std::unique_ptr<OpenedEngine> open_and_build_kge(const std::filesystem::path& repository_path) {
    auto engine = std::make_unique<OpenedEngine>(kFoundationVersion);
    engine->runtime.initialize();

    const oep::runtime::RuntimeResult opened = engine->runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    const oep::engine::KnowledgeGraphEngine::BuildResult built = engine->kge.build_graph();
    if (!built.success) {
        std::cerr << "oep: could not build the Knowledge Graph: " << built.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    return engine;
}

void print_object_ids(const std::vector<std::string>& object_ids) {
    if (object_ids.empty()) {
        std::cout << "  (none)\n";
        return;
    }
    for (const std::string& id : object_ids) {
        std::cout << "  " << id << "\n";
    }
}

// WP-EKE-003 `--category` names, matching oep::engine::to_string(QueryCategory)
// lowercased.
std::optional<oep::engine::QueryCategory> category_from_string(const std::string& value) {
    if (value == "object") return oep::engine::QueryCategory::Object;
    if (value == "relationship") return oep::engine::QueryCategory::Relationship;
    if (value == "domain") return oep::engine::QueryCategory::Domain;
    if (value == "type") return oep::engine::QueryCategory::Type;
    if (value == "dependency") return oep::engine::QueryCategory::Dependency;
    if (value == "neighborhood") return oep::engine::QueryCategory::Neighborhood;
    if (value == "path") return oep::engine::QueryCategory::Path;
    if (value == "reference") return oep::engine::QueryCategory::Reference;
    if (value == "metadata") return oep::engine::QueryCategory::Metadata;
    if (value == "composite") return oep::engine::QueryCategory::Composite;
    return std::nullopt;
}

const char* kRichQueryUsage =
    "Usage: oep engine <query|explain|profile> --category "
    "<object|relationship|domain|type|dependency|neighborhood|path|reference|metadata|composite> "
    "[--id <object-id>] [--secondary-id <object-id>] [--type <ObjectType>] [--domain <tag>] "
    "[--relationship <RelationshipType>] [--publisher <id>] [--package <id>] [--tags <tag1,tag2>] "
    "[--depth <n>] [--direction out|in|both] [--repository <path>]";

// Shared WP-EKE-003 rich query request parser used by `query`
// (--category mode), `explain`, and `profile`. Returns nullopt (having
// already printed a descriptive error) on failure.
std::optional<oep::engine::QueryRequest> parse_rich_query_request(const std::vector<std::string>& remaining) {
    std::optional<std::string> category_value;
    std::optional<std::string> id_value;
    std::optional<std::string> secondary_id_value;
    std::optional<std::string> domain_value;
    std::optional<std::string> type_value;
    std::optional<std::string> relationship_value;
    std::optional<std::string> publisher_value;
    std::optional<std::string> package_value;
    std::optional<std::string> tags_value;
    std::optional<int> depth_value;
    std::optional<std::string> direction_value;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--category" && has_value) {
            category_value = remaining[++i];
        } else if (flag == "--id" && has_value) {
            id_value = remaining[++i];
        } else if (flag == "--secondary-id" && has_value) {
            secondary_id_value = remaining[++i];
        } else if (flag == "--domain" && has_value) {
            domain_value = remaining[++i];
        } else if (flag == "--type" && has_value) {
            type_value = remaining[++i];
        } else if (flag == "--relationship" && has_value) {
            relationship_value = remaining[++i];
        } else if (flag == "--publisher" && has_value) {
            publisher_value = remaining[++i];
        } else if (flag == "--package" && has_value) {
            package_value = remaining[++i];
        } else if (flag == "--tags" && has_value) {
            tags_value = remaining[++i];
        } else if (flag == "--depth" && has_value) {
            const std::string& value = remaining[++i];
            char* end = nullptr;
            const long parsed = std::strtol(value.c_str(), &end, 10);
            if (end == value.c_str() || *end != '\0' || parsed < 0) {
                std::cerr << "oep: '--depth' requires a non-negative integer\n";
                return std::nullopt;
            }
            depth_value = static_cast<int>(parsed);
        } else if (flag == "--direction" && has_value) {
            direction_value = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << kRichQueryUsage << "\n";
            return std::nullopt;
        }
    }

    if (!category_value.has_value()) {
        std::cerr << "oep: '--category' is required\n";
        std::cerr << kRichQueryUsage << "\n";
        return std::nullopt;
    }
    const std::optional<oep::engine::QueryCategory> category = category_from_string(*category_value);
    if (!category.has_value()) {
        std::cerr << "oep: unrecognized --category '" << *category_value << "'\n";
        return std::nullopt;
    }

    oep::engine::QueryFilter filter;
    if (type_value.has_value()) {
        const std::optional<oep::repository::ObjectType> object_type =
            oep::repository::object_type_from_string(*type_value);
        if (!object_type.has_value()) {
            std::cerr << "oep: unrecognized object type '" << *type_value << "'\n";
            return std::nullopt;
        }
        filter.object_type = *object_type;
    }
    if (domain_value.has_value()) {
        filter.domain = *domain_value;
    }
    if (relationship_value.has_value()) {
        const std::optional<oep::repository::RelationshipType> relationship_type =
            oep::repository::relationship_type_from_string(*relationship_value);
        if (!relationship_type.has_value()) {
            std::cerr << "oep: unrecognized relationship type '" << *relationship_value << "'\n";
            return std::nullopt;
        }
        filter.relationship_type = *relationship_type;
    }
    if (publisher_value.has_value()) {
        filter.publisher_id = *publisher_value;
    }
    if (package_value.has_value()) {
        filter.package_id = *package_value;
    }
    if (tags_value.has_value()) {
        std::stringstream stream(*tags_value);
        std::string tag;
        while (std::getline(stream, tag, ',')) {
            if (!tag.empty()) filter.tags.push_back(tag);
        }
    }
    if (depth_value.has_value()) {
        filter.max_depth = *depth_value;
    }
    if (direction_value.has_value()) {
        if (*direction_value == "out") {
            filter.outgoing_only = true;
        } else if (*direction_value == "in") {
            filter.outgoing_only = false;
        } else if (*direction_value != "both") {
            std::cerr << "oep: unrecognized --direction '" << *direction_value << "' (expected 'out', 'in', or 'both')\n";
            return std::nullopt;
        }
    }

    return oep::engine::QueryRequest(*category, id_value.value_or(""), secondary_id_value.value_or(""), filter);
}

} // namespace

std::string EngineCommand::name() const {
    return "engine";
}

std::string EngineCommand::description() const {
    return "Query the Engineering Knowledge Runtime (WP-EKE-001), Knowledge Graph Engine (WP-EKE-002), and "
           "Engineering Query Engine (WP-EKE-003): Runtime Graph, Knowledge Graph build/validate/statistics/"
           "components/export, related objects, traversal, ten-category query planning/execution/caching";
}

int EngineCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'engine' requires a subcommand (load, stats, inspect, query, traverse, build, validate, "
                      "components, export, explain, cache, profile, clear-cache)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "load") return load(rest);
    if (subcommand == "stats") return stats(rest);
    if (subcommand == "inspect") return inspect(rest);
    if (subcommand == "query") return query(rest);
    if (subcommand == "traverse") return traverse(rest);
    if (subcommand == "build") return build(rest);
    if (subcommand == "validate") return validate(rest);
    if (subcommand == "components") return components(rest);
    if (subcommand == "export") return export_graph(rest);
    if (subcommand == "explain") return explain(rest);
    if (subcommand == "cache") return cache(rest);
    if (subcommand == "profile") return profile(rest);
    if (subcommand == "clear-cache") return clear_cache(rest);

    std::cerr << "oep: unknown 'engine' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int EngineCommand::load(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_load(repository_path);
    if (engine == nullptr) return 1;

    std::cout << "Objects loaded: " << engine->context.graph().object_count() << "\n";
    std::cout << "Relationships loaded: " << engine->context.graph().relationship_count() << "\n";

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::stats(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    // Enhanced (WP-EKE-002) to report the Knowledge Graph Engine's full
    // GraphStatistics rather than just the Runtime Graph's raw
    // object/relationship counts. The CLI talks to
    // KnowledgeGraphEngine::graph_statistics() directly (not through the
    // Public C API), so it has full access to the two distribution
    // vectors the C API's oep_graph_statistics_t deliberately omits
    // (see oep_api.h's WP-EKE-002 section for that scope decision).
    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::GraphStatistics stats = engine->kge.graph_statistics();
    std::cout << "Knowledge Graph:\n";
    std::cout << "  Objects: " << stats.object_count << "\n";
    std::cout << "  Relationships: " << stats.relationship_count << "\n";
    std::cout << "  Connected components: " << stats.connected_component_count << "\n";
    std::cout << "  Density: " << stats.density << "\n";
    std::cout << "  Maximum depth: " << stats.maximum_depth << "\n";
    std::cout << "  Average degree: " << stats.average_degree << "\n";
    std::cout << "  Relationship distribution:\n";
    if (stats.relationship_distribution.empty()) {
        std::cout << "    (none)\n";
    } else {
        for (const oep::engine::RelationshipTypeCount& entry : stats.relationship_distribution) {
            std::cout << "    " << oep::repository::to_string(entry.type) << ": " << entry.count << "\n";
        }
    }
    std::cout << "  Domain distribution:\n";
    if (stats.domain_distribution.empty()) {
        std::cout << "    (none)\n";
    } else {
        for (const oep::engine::DomainCount& entry : stats.domain_distribution) {
            std::cout << "    " << entry.domain << ": " << entry.count << "\n";
        }
    }

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::inspect(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'engine inspect' requires an object ID\n";
        std::cerr << "Usage: oep engine inspect <object-id> [--repository <path>]\n";
        return 1;
    }
    const std::string object_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_load(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::ObjectLoader::LoadObjectResult loaded = engine->context.load_object(object_id);
    if (!loaded.success) {
        std::cerr << "oep: could not load object: " << loaded.error << "\n";
        engine->runtime.shutdown();
        return 1;
    }
    if (!loaded.found) {
        std::cerr << "oep: no object found with id '" << object_id << "'\n";
        engine->runtime.shutdown();
        return 1;
    }

    std::cout << "ID: " << loaded.object.object_id << "\n";
    std::cout << "Type: " << oep::repository::to_string(loaded.object.object_type) << "\n";
    std::cout << "Name: " << loaded.object.name << "\n";
    std::cout << "Author: " << loaded.object.author << "\n";
    std::cout << "Version: " << loaded.object.version << "\n";
    std::cout << "Description: " << loaded.object.description << "\n";
    std::cout << "Tags:";
    for (const std::string& tag : loaded.object.tags) {
        std::cout << " " << tag;
    }
    std::cout << "\n";

    const oep::engine::RelatedObjectsResult related = engine->context.related_objects(object_id);
    std::cout << "Related objects:\n";
    if (!related.success) {
        std::cerr << "oep: could not compute related objects: " << related.error << "\n";
        engine->runtime.shutdown();
        return 1;
    }
    print_object_ids(related.object_ids);

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::query(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    // WP-EKE-003: `--category` opts into the richer, ten-category
    // Engineering Query Engine instead of WP-EKE-001's original
    // by-id/by-type/by-domain/by-relationship lookup below -- see this
    // file's class-level doc comment for the backward-compatibility
    // rationale. Every existing invocation without `--category` is
    // unaffected.
    if (std::find(remaining.begin(), remaining.end(), "--category") != remaining.end()) {
        const std::optional<oep::engine::QueryRequest> request = parse_rich_query_request(remaining);
        if (!request.has_value()) return 1;

        const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
        if (engine == nullptr) return 1;

        const oep::engine::EngineeringQueryResult result = engine->eqe.execute_query(*request);
        std::cout << "Category: " << oep::engine::to_string(request->category()) << "\n";
        std::cout << "Objects (" << result.object_ids().size() << "):\n";
        print_object_ids(result.object_ids());
        std::cout << "Relationships (" << result.relationship_ids().size() << "):\n";
        print_object_ids(result.relationship_ids());
        std::cout << "Result count: " << result.statistics().result_count << "\n";
        std::cout << "Traversal summary: " << result.traversal_summary() << "\n";

        engine->runtime.shutdown();
        return 0;
    }

    std::optional<std::string> id_value;
    std::optional<std::string> type_value;
    std::optional<std::string> domain_value;
    std::optional<std::string> relationship_value;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--id" && has_value) {
            id_value = remaining[++i];
        } else if (flag == "--type" && has_value) {
            type_value = remaining[++i];
        } else if (flag == "--domain" && has_value) {
            domain_value = remaining[++i];
        } else if (flag == "--relationship" && has_value) {
            relationship_value = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << "Usage: oep engine query --id <object-id> | --type <ObjectType> | --domain <tag> | "
                         "--relationship <RelationshipType> [--repository <path>]\n";
            return 1;
        }
    }

    const int selectors_given = (id_value.has_value() ? 1 : 0) + (type_value.has_value() ? 1 : 0) +
                                 (domain_value.has_value() ? 1 : 0) + (relationship_value.has_value() ? 1 : 0);
    if (selectors_given != 1) {
        std::cerr << "oep: 'engine query' requires exactly one of --id, --type, --domain, --relationship\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_load(repository_path);
    if (engine == nullptr) return 1;

    oep::engine::EngineeringContext::QueryRequest request;
    if (id_value.has_value()) {
        request.kind = oep::engine::EngineeringContext::QueryKind::ById;
        request.object_id = *id_value;
    } else if (type_value.has_value()) {
        const std::optional<oep::repository::ObjectType> object_type =
            oep::repository::object_type_from_string(*type_value);
        if (!object_type.has_value()) {
            std::cerr << "oep: unrecognized object type '" << *type_value << "'\n";
            engine->runtime.shutdown();
            return 1;
        }
        request.kind = oep::engine::EngineeringContext::QueryKind::ByType;
        request.object_type = *object_type;
    } else if (domain_value.has_value()) {
        request.kind = oep::engine::EngineeringContext::QueryKind::ByDomain;
        request.domain = *domain_value;
    } else {
        const std::optional<oep::repository::RelationshipType> relationship_type =
            oep::repository::relationship_type_from_string(*relationship_value);
        if (!relationship_type.has_value()) {
            std::cerr << "oep: unrecognized relationship type '" << *relationship_value << "'\n";
            engine->runtime.shutdown();
            return 1;
        }
        request.kind = oep::engine::EngineeringContext::QueryKind::ByRelationship;
        request.relationship_type = *relationship_type;
    }

    const oep::engine::QueryResult result = engine->context.query(request);
    if (!result.success) {
        std::cerr << "oep: query failed: " << result.error << "\n";
        engine->runtime.shutdown();
        return 1;
    }

    std::cout << "Matching objects:\n";
    print_object_ids(result.object_ids);

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::traverse(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    std::string order = "bfs";
    std::optional<std::string> relationship_value;
    std::optional<int> max_depth;

    std::vector<std::string> positional;
    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--order" && has_value) {
            order = remaining[++i];
        } else if (flag == "--relationship" && has_value) {
            relationship_value = remaining[++i];
        } else if (flag == "--max-depth" && has_value) {
            const std::string& value = remaining[++i];
            char* end = nullptr;
            const long parsed = std::strtol(value.c_str(), &end, 10);
            if (end == value.c_str() || *end != '\0' || parsed < 0) {
                std::cerr << "oep: '--max-depth' requires a non-negative integer\n";
                return 1;
            }
            max_depth = static_cast<int>(parsed);
        } else if (!flag.empty() && flag[0] == '-') {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            return 1;
        } else {
            positional.push_back(flag);
        }
    }

    if (order != "bfs" && order != "dfs") {
        std::cerr << "oep: unrecognized --order '" << order << "' (expected 'bfs' or 'dfs')\n";
        return 1;
    }
    if (positional.empty()) {
        std::cerr << "oep: 'engine traverse' requires a start object ID\n";
        std::cerr << "Usage: oep engine traverse <start-object-id> [--order bfs|dfs] "
                     "[--relationship <RelationshipType>] [--max-depth N] [--repository <path>]\n";
        return 1;
    }
    const std::string& start_object_id = positional.front();

    oep::engine::TraversalOptions options;
    options.order = order == "dfs" ? oep::engine::TraversalOrder::DepthFirst : oep::engine::TraversalOrder::BreadthFirst;
    if (max_depth.has_value()) {
        options.max_depth = *max_depth;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_load(repository_path);
    if (engine == nullptr) return 1;

    if (relationship_value.has_value()) {
        const std::optional<oep::repository::RelationshipType> relationship_type =
            oep::repository::relationship_type_from_string(*relationship_value);
        if (!relationship_type.has_value()) {
            std::cerr << "oep: unrecognized relationship type '" << *relationship_value << "'\n";
            engine->runtime.shutdown();
            return 1;
        }
        options.relationship_type_filter = *relationship_type;
    }

    const oep::engine::TraversalResult result = engine->context.traverse(start_object_id, options);
    if (!result.success) {
        std::cerr << "oep: traversal failed: " << result.error << "\n";
        engine->runtime.shutdown();
        return 1;
    }

    std::cout << "Traversal (" << (order == "dfs" ? "DFS" : "BFS") << "):\n";
    for (std::size_t i = 0; i < result.object_ids.size(); ++i) {
        std::cout << "  " << (i + 1) << "\t" << result.object_ids[i] << "\n";
    }

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::build(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    std::cout << "Objects: " << engine->kge.graph().node_count() << "\n";
    std::cout << "Relationships: " << engine->kge.graph().edge_count() << "\n";

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::validate(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::GraphValidationReport report = engine->kge.validate_graph();
    std::cout << "Valid: " << (report.valid() ? "yes" : "no") << "\n";
    if (!report.issues().empty()) {
        std::cout << "Issues:\n";
        for (const oep::engine::GraphIssue& issue : report.issues()) {
            std::cout << "  " << oep::engine::to_string(issue.kind);
            if (!issue.relationship_id.empty()) {
                std::cout << " [" << issue.relationship_id << "]";
            }
            std::cout << ": " << issue.detail << "\n";
        }
    }

    engine->runtime.shutdown();
    return report.valid() ? 0 : 1;
}

int EngineCommand::components(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::ComponentsResult result = engine->kge.connected_components();
    if (!result.success) {
        std::cerr << "oep: could not compute connected components: " << result.error << "\n";
        engine->runtime.shutdown();
        return 1;
    }

    std::cout << "Connected components: " << result.components.size() << "\n";
    if (result.components.empty()) {
        std::cout << "  (none)\n";
    } else {
        for (const std::vector<std::string>& component : result.components) {
            for (std::size_t i = 0; i < component.size(); ++i) {
                if (i != 0) std::cout << " ";
                std::cout << component[i];
            }
            std::cout << "\n";
        }
    }

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::export_graph(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    std::optional<std::string> format_value;
    std::vector<std::string> unrecognized;
    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--format" && has_value) {
            format_value = remaining[++i];
        } else {
            unrecognized.push_back(flag);
        }
    }
    if (!unrecognized.empty()) {
        std::cerr << "oep: unrecognized argument '" << unrecognized.front() << "'\n";
        return 1;
    }
    if (!format_value.has_value()) {
        std::cerr << "oep: 'engine export' requires --format json|graphml\n";
        std::cerr << "Usage: oep engine export --format json|graphml [--repository <path>]\n";
        return 1;
    }
    if (*format_value != "json" && *format_value != "graphml") {
        std::cerr << "oep: unrecognized --format '" << *format_value << "' (expected 'json' or 'graphml')\n";
        return 1;
    }

    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    if (*format_value == "json") {
        std::cout << engine->kge.export_json() << "\n";
    } else {
        std::cout << engine->kge.export_graphml_placeholder() << "\n";
    }

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::explain(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    const std::optional<oep::engine::QueryRequest> request = parse_rich_query_request(remaining);
    if (!request.has_value()) return 1;

    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::QueryPlan plan = engine->eqe.plan_query(*request);
    std::cout << "Category: " << oep::engine::to_string(plan.category()) << "\n";
    std::cout << "Strategy: " << oep::engine::to_string(plan.strategy()) << "\n";
    std::cout << "Estimated cost: " << plan.estimated_cost() << "\n";
    std::cout << "Indexes used:\n";
    print_object_ids(plan.indexes_used());
    std::cout << "Execution order preview (" << plan.execution_order().size() << " ids):\n";
    print_object_ids(plan.execution_order());

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::cache(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    // A fresh CLI invocation has no engine state left over from a prior
    // `oep engine query`/`explain`/`profile` call (this command group is
    // self-contained per invocation, see this file's class-level doc
    // comment) -- so, run alone, this reports an empty cache. Its value
    // is mainly diagnostic/scripting: confirming clear-cache's effect,
    // or as a building block for a future long-lived engine process.
    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::QueryCache& query_cache = engine->eqe.query_cache();
    std::cout << "Cached plans: " << query_cache.plan_count() << "\n";
    std::cout << "Cached results: " << query_cache.result_count() << "\n";

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::profile(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    const std::optional<oep::engine::QueryRequest> request = parse_rich_query_request(remaining);
    if (!request.has_value()) return 1;

    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::EngineeringQueryResult result = engine->eqe.execute_query(*request);
    const oep::engine::QueryStatistics& stats = result.statistics();
    std::cout << "Category: " << oep::engine::to_string(request->category()) << "\n";
    std::cout << "Execution time (ms): " << stats.execution_time_ms << "\n";
    std::cout << "Objects examined: " << stats.objects_examined << "\n";
    std::cout << "Relationships examined: " << stats.relationships_examined << "\n";
    std::cout << "Traversal depth: " << stats.traversal_depth << "\n";
    std::cout << "Result count: " << stats.result_count << "\n";
    std::cout << "Indexes used:\n";
    print_object_ids(stats.indexes_used);
    std::cout << "Traversal summary: " << result.traversal_summary() << "\n";

    engine->runtime.shutdown();
    return 0;
}

int EngineCommand::clear_cache(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    // Same self-contained-per-invocation caveat as `cache` above: this
    // clears whatever this one process's EngineeringQueryEngine
    // accumulated (nothing, for a bare `oep engine clear-cache`) --
    // included for completeness and for callers embedding this as one
    // step in a longer-lived process/script.
    const std::unique_ptr<OpenedEngine> engine = open_and_build_kge(repository_path);
    if (engine == nullptr) return 1;

    engine->eqe.clear_query_cache();
    std::cout << "Query cache cleared.\n";

    engine->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands

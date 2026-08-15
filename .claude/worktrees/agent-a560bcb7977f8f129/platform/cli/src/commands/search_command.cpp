#include "search_command.hpp"

#include <filesystem>
#include <iostream>

#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

bool matches_object_filters(const oep::repository::EngineeringObject& object, const std::string& type_filter,
                             const std::string& author_filter, const std::string& tag_filter) {
    if (!type_filter.empty() && oep::repository::to_string(object.object_type) != type_filter) {
        return false;
    }
    if (!author_filter.empty() && object.author != author_filter) {
        return false;
    }
    if (!tag_filter.empty()) {
        bool found = false;
        for (const std::string& tag : object.tags) {
            if (tag == tag_filter) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

bool matches_relationship_filters(const oep::repository::Relationship& relationship, const std::string& type_filter,
                                   const std::string& author_filter) {
    if (!type_filter.empty() && oep::repository::to_string(relationship.relationship_type) != type_filter) {
        return false;
    }
    if (!author_filter.empty() && relationship.author != author_filter) {
        return false;
    }
    return true;
}

} // namespace

std::string SearchCommand::name() const {
    return "search";
}

std::string SearchCommand::description() const {
    return "Search Engineering Objects and Relationships";
}

int SearchCommand::execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    std::string type_filter;
    std::string author_filter;
    std::string tag_filter;
    std::vector<std::string> positional;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--type" && has_value) {
            type_filter = remaining[++i];
        } else if (flag == "--author" && has_value) {
            author_filter = remaining[++i];
        } else if (flag == "--tag" && has_value) {
            tag_filter = remaining[++i];
        } else {
            positional.push_back(flag);
        }
    }

    bool search_objects_flag = true;
    bool search_relationships_flag = true;
    std::string query;

    if (!positional.empty() && positional[0] == "objects") {
        search_relationships_flag = false;
        if (positional.size() < 2) {
            std::cerr << "oep: 'search objects' requires a query\n";
            return 1;
        }
        query = positional[1];
    } else if (!positional.empty() && positional[0] == "relationships") {
        search_objects_flag = false;
        if (positional.size() < 2) {
            std::cerr << "oep: 'search relationships' requires a query\n";
            return 1;
        }
        query = positional[1];
    } else if (!positional.empty()) {
        query = positional[0];
    } else {
        std::cerr << "oep: 'search' requires a query\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    int exit_code = 0;
    if (search_objects_flag) {
        exit_code |= print_object_results(runtime, query, type_filter, author_filter, tag_filter);
    }
    if (search_relationships_flag) {
        exit_code |= print_relationship_results(runtime, query, type_filter, author_filter);
    }

    runtime.shutdown();
    return exit_code;
}

int SearchCommand::print_object_results(oep::runtime::FoundationRuntime& runtime, const std::string& query,
                                         const std::string& type_filter, const std::string& author_filter,
                                         const std::string& tag_filter) const {
    const oep::search::SearchObjectsResult result = runtime.search_engine()->search_objects(query);
    if (!result.success) {
        std::cerr << "oep: object search failed: " << result.error << "\n";
        return 1;
    }

    std::cout << "Objects:\n";
    bool printed_any = false;
    for (const oep::search::ObjectSearchResult& hit : result.results) {
        const oep::repository::LoadObjectResult loaded = runtime.object_store()->load(hit.object_id);
        if (!loaded.success || !matches_object_filters(loaded.object, type_filter, author_filter, tag_filter)) {
            continue;
        }

        std::cout << "  " << hit.object_id << "\t" << oep::repository::to_string(hit.object_type) << "\t"
                   << hit.display_name << "\t" << hit.match_score << "\t"
                   << oep::search::to_string(hit.match_location) << "\n";
        printed_any = true;
    }
    if (!printed_any) {
        std::cout << "  No matching objects found.\n";
    }
    return 0;
}

int SearchCommand::print_relationship_results(oep::runtime::FoundationRuntime& runtime, const std::string& query,
                                               const std::string& type_filter,
                                               const std::string& author_filter) const {
    const oep::search::SearchRelationshipsResult result = runtime.search_engine()->search_relationships(query);
    if (!result.success) {
        std::cerr << "oep: relationship search failed: " << result.error << "\n";
        return 1;
    }

    std::cout << "Relationships:\n";
    bool printed_any = false;
    for (const oep::search::RelationshipSearchResult& hit : result.results) {
        const oep::repository::LoadRelationshipResult loaded = runtime.relationship_store()->load(hit.relationship_id);
        if (!loaded.success || !matches_relationship_filters(loaded.relationship, type_filter, author_filter)) {
            continue;
        }

        std::cout << "  " << hit.relationship_id << "\t" << oep::repository::to_string(hit.relationship_type) << "\t"
                   << hit.source_object_id << "\t" << hit.target_object_id << "\t" << hit.match_score << "\t"
                   << oep::search::to_string(hit.match_location) << "\n";
        printed_any = true;
    }
    if (!printed_any) {
        std::cout << "  No matching relationships found.\n";
    }
    return 0;
}

} // namespace oep::cli::commands

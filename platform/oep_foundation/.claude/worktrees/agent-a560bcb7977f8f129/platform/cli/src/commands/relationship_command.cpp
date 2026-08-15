#include "relationship_command.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string RelationshipCommand::name() const {
    return "relationship";
}

std::string RelationshipCommand::description() const {
    return "Create, list, show, and delete Relationships";
}

int RelationshipCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'relationship' requires a subcommand (create, list, show, delete)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "create") return create(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "show") return show(rest);
    if (subcommand == "delete") return remove(rest);

    std::cerr << "oep: unknown 'relationship' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int RelationshipCommand::create(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    std::string source_id;
    std::string target_id;
    std::string type_name;
    std::string author;
    std::string description;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--source" && has_value) {
            source_id = remaining[++i];
        } else if (flag == "--target" && has_value) {
            target_id = remaining[++i];
        } else if (flag == "--type" && has_value) {
            type_name = remaining[++i];
        } else if (flag == "--author" && has_value) {
            author = remaining[++i];
        } else if (flag == "--description" && has_value) {
            description = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << "Usage: oep relationship create --source <object-id> --target <object-id> "
                         "--type <type> [--author <name>] [--description <text>] [--repository <path>]\n";
            return 1;
        }
    }

    if (source_id.empty() || target_id.empty() || type_name.empty()) {
        std::cerr << "oep: 'relationship create' requires --source, --target, and --type\n";
        return 1;
    }

    const std::optional<oep::repository::RelationshipType> relationship_type =
        oep::repository::relationship_type_from_string(type_name);
    if (!relationship_type.has_value()) {
        std::cerr << "oep: unrecognized relationship type '" << type_name << "'\n";
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

    // Through the Runtime's own mutation method (WP-REP-003) rather than
    // the store directly, so the create executes inside a Repository
    // Transaction and is journaled like every other write.
    const oep::runtime::RuntimeRelationshipMutationResult created =
        runtime.create_relationship(source_id, target_id, *relationship_type, author, description);
    if (!created.success) {
        std::cerr << "oep: could not create relationship: " << created.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Created relationship '" << created.relationship.relationship_id << "' ("
               << oep::repository::to_string(created.relationship.relationship_type) << ") '"
               << created.relationship.source_object_id << "' -> '" << created.relationship.target_object_id
               << "'\n";

    runtime.shutdown();
    return 0;
}

int RelationshipCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::ListRelationshipsResult listed = runtime.relationship_store()->list_all();
    if (!listed.success) {
        std::cerr << "oep: could not list relationships: " << listed.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::vector<oep::repository::Relationship> relationships = listed.relationships;
    std::sort(relationships.begin(), relationships.end(),
              [](const oep::repository::Relationship& a, const oep::repository::Relationship& b) {
                  return a.relationship_id < b.relationship_id;
              });

    if (relationships.empty()) {
        std::cout << "No relationships found.\n";
    } else {
        for (const oep::repository::Relationship& relationship : relationships) {
            std::cout << relationship.relationship_id << "\t"
                       << oep::repository::to_string(relationship.relationship_type) << "\t"
                       << relationship.source_object_id << "\t" << relationship.target_object_id << "\n";
        }
    }

    runtime.shutdown();
    return 0;
}

int RelationshipCommand::show(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'relationship show' requires a relationship ID\n";
        std::cerr << "Usage: oep relationship show <relationship-id> [--repository <path>]\n";
        return 1;
    }
    const std::string& relationship_id = remaining[0];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::LoadRelationshipResult loaded = runtime.relationship_store()->load(relationship_id);
    if (!loaded.success) {
        std::cerr << "oep: could not show relationship: " << loaded.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::Relationship& relationship = loaded.relationship;
    std::cout << "Relationship ID:  " << relationship.relationship_id << "\n";
    std::cout << "Type:             " << oep::repository::to_string(relationship.relationship_type) << "\n";
    std::cout << "Source Object ID: " << relationship.source_object_id << "\n";
    std::cout << "Target Object ID: " << relationship.target_object_id << "\n";
    std::cout << "Author:           " << relationship.author << "\n";
    std::cout << "Description:      " << relationship.description << "\n";
    std::cout << "Created:          " << relationship.created_utc << "\n";

    runtime.shutdown();
    return 0;
}

int RelationshipCommand::remove(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'relationship delete' requires a relationship ID\n";
        std::cerr << "Usage: oep relationship delete <relationship-id> [--repository <path>]\n";
        return 1;
    }
    const std::string& relationship_id = remaining[0];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    // Through the Runtime (WP-REP-003): the delete runs inside a
    // Repository Transaction and is journaled.
    const oep::runtime::RuntimeResult removed = runtime.delete_relationship(relationship_id);
    if (!removed.success) {
        std::cerr << "oep: could not delete relationship: " << removed.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Deleted relationship '" << relationship_id << "'\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands

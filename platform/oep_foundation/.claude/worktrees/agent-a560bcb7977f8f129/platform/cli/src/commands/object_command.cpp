#include "object_command.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string ObjectCommand::name() const {
    return "object";
}

std::string ObjectCommand::description() const {
    return "Create, list, show, and delete Engineering Objects";
}

int ObjectCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'object' requires a subcommand (create, list, show, delete)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "create") return create(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "show") return show(rest);
    if (subcommand == "delete") return remove(rest);

    std::cerr << "oep: unknown 'object' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int ObjectCommand::create(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    std::string type_name;
    std::string object_name;
    std::string description;
    std::string author;
    std::string tags_csv;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--type" && has_value) {
            type_name = remaining[++i];
        } else if (flag == "--name" && has_value) {
            object_name = remaining[++i];
        } else if (flag == "--description" && has_value) {
            description = remaining[++i];
        } else if (flag == "--author" && has_value) {
            author = remaining[++i];
        } else if (flag == "--tags" && has_value) {
            tags_csv = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << "Usage: oep object create --type <type> --name <name> "
                         "[--description <text>] [--author <name>] [--tags a,b,c] [--repository <path>]\n";
            return 1;
        }
    }

    if (type_name.empty() || object_name.empty()) {
        std::cerr << "oep: 'object create' requires --type and --name\n";
        return 1;
    }

    const std::optional<oep::repository::ObjectType> object_type = oep::repository::object_type_from_string(type_name);
    if (!object_type.has_value()) {
        std::cerr << "oep: unrecognized object type '" << type_name << "'\n";
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
    const oep::runtime::RuntimeObjectMutationResult created =
        runtime.create_object(*object_type, object_name, description, author, split_csv(tags_csv));
    if (!created.success) {
        std::cerr << "oep: could not create object: " << created.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Created object '" << created.object.object_id << "' ("
               << oep::repository::to_string(created.object.object_type) << ") '" << created.object.name << "'\n";

    runtime.shutdown();
    return 0;
}

int ObjectCommand::list(const std::vector<std::string>& args) const {
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

    const oep::repository::ListObjectsResult listed = runtime.object_store()->list_all();
    if (!listed.success) {
        std::cerr << "oep: could not list objects: " << listed.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::vector<oep::repository::EngineeringObject> objects = listed.objects;
    std::sort(objects.begin(), objects.end(),
              [](const oep::repository::EngineeringObject& a, const oep::repository::EngineeringObject& b) {
                  return a.object_id < b.object_id;
              });

    if (objects.empty()) {
        std::cout << "No objects found.\n";
    } else {
        for (const oep::repository::EngineeringObject& object : objects) {
            std::cout << object.object_id << "\t" << oep::repository::to_string(object.object_type) << "\t"
                       << object.name << "\t" << object.version << "\n";
        }
    }

    runtime.shutdown();
    return 0;
}

int ObjectCommand::show(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'object show' requires an object ID\n";
        std::cerr << "Usage: oep object show <object-id> [--repository <path>]\n";
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

    const oep::repository::LoadObjectResult loaded = runtime.object_store()->load(object_id);
    if (!loaded.success) {
        std::cerr << "oep: could not show object: " << loaded.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::repository::EngineeringObject& object = loaded.object;
    std::cout << "Object ID:        " << object.object_id << "\n";
    std::cout << "Object Type:      " << oep::repository::to_string(object.object_type) << "\n";
    std::cout << "Name:             " << object.name << "\n";
    std::cout << "Description:      " << object.description << "\n";
    std::cout << "Author:           " << object.author << "\n";
    std::cout << "Tags:             ";
    for (std::size_t i = 0; i < object.tags.size(); ++i) {
        std::cout << object.tags[i];
        if (i + 1 != object.tags.size()) std::cout << ", ";
    }
    std::cout << "\n";
    std::cout << "Version:          " << object.version << "\n";
    std::cout << "Created:          " << object.created_utc << "\n";
    std::cout << "Last Modified:    " << object.last_modified_utc << "\n";

    runtime.shutdown();
    return 0;
}

int ObjectCommand::remove(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'object delete' requires an object ID\n";
        std::cerr << "Usage: oep object delete <object-id> [--repository <path>]\n";
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

    // Through the Runtime (WP-REP-003): the delete runs inside a
    // Repository Transaction and is journaled.
    const oep::runtime::RuntimeResult removed = runtime.delete_object(object_id);
    if (!removed.success) {
        std::cerr << "oep: could not delete object: " << removed.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Deleted object '" << object_id << "'\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands

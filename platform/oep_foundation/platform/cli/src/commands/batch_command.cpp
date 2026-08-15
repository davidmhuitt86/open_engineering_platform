#include "batch_command.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <utility>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Returns {success, contents-or-error}.
std::pair<bool, std::string> read_input_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'"};
    }
    std::ostringstream stream;
    stream << file.rdbuf();
    return {true, stream.str()};
}

} // namespace

std::string BatchCommand::name() const {
    return "batch";
}

std::string BatchCommand::description() const {
    return "Create, delete, and validate batches of Engineering Objects and Relationships";
}

int BatchCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'batch' requires a subcommand (create, delete, validate)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "create") return create(rest);
    if (subcommand == "delete") return remove(rest);
    if (subcommand == "validate") return validate(rest);

    std::cerr << "oep: unknown 'batch' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int BatchCommand::create(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'batch create' requires an input file\n";
        std::cerr << "Usage: oep batch create <input-file> [--repository <path>]\n";
        return 1;
    }

    const auto [read_ok, contents_or_error] = read_input_file(remaining[0]);
    if (!read_ok) {
        std::cerr << "oep: " << contents_or_error << "\n";
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

    const oep::runtime::RuntimeBatchCreateResult result = runtime.execute_batch_create(contents_or_error);
    if (!result.success) {
        std::cerr << "oep: batch create failed: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Batch create succeeded.\n";
    std::cout << "  Objects created:       " << result.objects_created << "\n";
    std::cout << "  Relationships created: " << result.relationships_created << "\n";

    runtime.shutdown();
    return 0;
}

int BatchCommand::remove(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'batch delete' requires an input file\n";
        std::cerr << "Usage: oep batch delete <input-file> [--repository <path>]\n";
        return 1;
    }

    const auto [read_ok, contents_or_error] = read_input_file(remaining[0]);
    if (!read_ok) {
        std::cerr << "oep: " << contents_or_error << "\n";
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

    const oep::runtime::RuntimeBatchDeleteResult result = runtime.execute_batch_delete(contents_or_error);
    if (!result.success) {
        std::cerr << "oep: batch delete failed: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Batch delete succeeded.\n";
    std::cout << "  Objects deleted:       " << result.objects_deleted << "\n";
    std::cout << "  Relationships deleted: " << result.relationships_deleted << "\n";

    runtime.shutdown();
    return 0;
}

int BatchCommand::validate(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'batch validate' requires an input file\n";
        std::cerr << "Usage: oep batch validate <input-file> [--repository <path>]\n";
        return 1;
    }

    const auto [read_ok, contents_or_error] = read_input_file(remaining[0]);
    if (!read_ok) {
        std::cerr << "oep: " << contents_or_error << "\n";
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

    const oep::runtime::RuntimeBatchValidateResult result = runtime.validate_batch_create(contents_or_error);
    if (!result.success) {
        std::cerr << "oep: could not validate batch: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    if (result.findings.empty()) {
        std::cout << "Batch is valid.\n";
        runtime.shutdown();
        return 0;
    }

    std::cout << "Batch is invalid:\n";
    for (const std::string& finding : result.findings) {
        std::cout << "  " << finding << "\n";
    }

    runtime.shutdown();
    return 1;
}

} // namespace oep::cli::commands

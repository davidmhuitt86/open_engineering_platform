#include "session_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>

#include "intelligence_common.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string SessionCommand::name() const {
    return "session";
}

std::string SessionCommand::description() const {
    return "Manage Knowledge Sessions on the Engineering Intelligence Platform (WP-EKE-007): create, list, close";
}

int SessionCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'session' requires a subcommand (create, list, close)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "create") return create(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "close") return close(rest);

    std::cerr << "oep: unknown 'session' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int SessionCommand::create(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    const std::string session_id = platform->eip.create_session();
    std::cout << "Session created: " << session_id << "\n";
    std::cout << "Note: KnowledgeSessions are held in-memory and process-local (see intelligence_common.hpp) -- "
                 "this session_id cannot be found by a later, separate 'oep session' invocation. Use 'oep workflow' "
                 "to create-and-run a session-scoped workflow in one invocation.\n";

    platform->runtime.shutdown();
    return 0;
}

int SessionCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    const std::vector<std::string> sessions = platform->eip.list_sessions();
    std::cout << "Sessions (" << sessions.size() << "):\n";
    if (sessions.empty()) {
        std::cout << "  (none -- KnowledgeSessions are process-local; no session exists in a fresh invocation "
                     "until 'oep session create' or 'oep workflow' is run first, in the SAME invocation)\n";
    } else {
        for (const std::string& session_id : sessions) {
            std::cout << "  " << session_id << "\n";
        }
    }

    platform->runtime.shutdown();
    return 0;
}

int SessionCommand::close(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'session close' requires a session ID\n";
        std::cerr << "Usage: oep session close <session-id> [--repository <path>]\n";
        return 1;
    }
    const std::string session_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    if (!platform->eip.close_session(session_id)) {
        std::cerr << "oep: session_id '" << session_id
                   << "' was not found on this handle (KnowledgeSessions are process-local -- see "
                      "intelligence_common.hpp)\n";
        platform->runtime.shutdown();
        return 1;
    }

    std::cout << "Session closed: " << session_id << "\n";
    platform->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands

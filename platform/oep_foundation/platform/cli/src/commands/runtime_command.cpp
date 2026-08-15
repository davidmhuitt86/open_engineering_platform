#include "runtime_command.hpp"

#include <cstdlib>
#include <iostream>
#include <vector>

#include "oep/runtime/repository_events.hpp"
#include "repository_path_option.hpp"
#include "runtime_event_log.hpp"

namespace oep::cli::commands {

std::string RuntimeCommand::name() const {
    return "runtime";
}

std::string RuntimeCommand::description() const {
    return "Inspect Runtime Service state, including the Repository Events log";
}

int RuntimeCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'runtime' requires a subcommand (events)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "events") return events(rest);

    std::cerr << "oep: unknown 'runtime' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int RuntimeCommand::events(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    // Accepted for consistency with the rest of the CLI's per-repository
    // commands, though the Repository Events log (WP-REP-006) is a
    // process-wide, in-memory log rather than something read from a
    // specific repository on disk — see runtime_event_log.hpp.
    (void)extract_repository_path(remaining);

    std::size_t limit = 0;
    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--limit" && has_value) {
            const std::string& value = remaining[++i];
            char* end = nullptr;
            const long parsed = std::strtol(value.c_str(), &end, 10);
            if (end == value.c_str() || *end != '\0' || parsed < 0) {
                std::cerr << "oep: '--limit' requires a non-negative integer\n";
                return 1;
            }
            limit = static_cast<std::size_t>(parsed);
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << "Usage: " << usage() << "\n";
            return 1;
        }
    }

    const std::vector<oep::runtime::RepositoryEvent> events = global_event_bus().recent_events(limit);
    if (events.empty()) {
        std::cout << "No repository events recorded.\n";
        return 0;
    }

    for (const oep::runtime::RepositoryEvent& event : events) {
        std::cout << event.sequence() << "\t" << event.occurred_at_utc() << "\t"
                  << oep::runtime::to_string(event.type()) << "\t" << event.subject_id() << "\t" << event.detail()
                  << "\n";
    }
    return 0;
}

} // namespace oep::cli::commands

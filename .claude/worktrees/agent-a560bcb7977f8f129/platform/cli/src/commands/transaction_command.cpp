#include "transaction_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

template <typename Work>
int with_open_repository(const std::filesystem::path& repository_path, Work&& work) {
    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const int exit_code = work(runtime);
    runtime.shutdown();
    return exit_code;
}

} // namespace

std::string TransactionCommand::name() const {
    return "transaction";
}

std::string TransactionCommand::description() const {
    return "Inspect the Repository Transaction Engine's journal";
}

int TransactionCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'transaction' requires a subcommand (list, show)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "list") return list(rest);
    if (subcommand == "show") return show(rest);

    std::cerr << "oep: unknown 'transaction' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int TransactionCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    return with_open_repository(repository_path, [](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
        if (!history.success) {
            std::cerr << "oep: could not read the transaction journal: " << history.error << "\n";
            return 1;
        }
        if (history.records.empty()) {
            std::cout << "No journaled transactions.\n";
        } else {
            for (const oep::runtime::TransactionRecord& record : history.records) {
                std::cout << record.transaction_id << "\t" << oep::runtime::to_string(record.state) << "\t"
                          << record.description << "\t" << record.entries.size() << " operation(s)\t"
                          << record.opened_utc << "\n";
            }
        }
        return 0;
    });
}

int TransactionCommand::show(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'transaction show' requires a transaction id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string transaction_id = remaining[0];

    return with_open_repository(repository_path, [&transaction_id](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeTransactionRecordResult loaded = runtime.get_transaction_record(transaction_id);
        if (!loaded.success) {
            std::cerr << "oep: " << loaded.error << "\n";
            return 1;
        }
        const oep::runtime::TransactionRecord& record = loaded.record;
        std::cout << "Transaction ID: " << record.transaction_id << "\n";
        std::cout << "State:          " << oep::runtime::to_string(record.state) << "\n";
        std::cout << "Description:    " << record.description << "\n";
        std::cout << "Opened:         " << record.opened_utc << "\n";
        std::cout << "Closed:         " << record.closed_utc << "\n";
        std::cout << "Operations (" << record.entries.size() << "):\n";
        for (const oep::runtime::JournalEntry& entry : record.entries) {
            std::cout << "  " << entry.operation << "\t" << entry.target_id << "\t" << entry.previous_state
                      << " -> " << entry.new_state << "\t" << entry.timestamp_utc << "\n";
        }
        return 0;
    });
}

} // namespace oep::cli::commands

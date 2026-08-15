#include "oep/runtime/transaction_journal.hpp"

#include <algorithm>
#include <fstream>
#include <sstream>
#include <system_error>

#include "oep/repository/json_value.hpp"

namespace oep::runtime {

namespace {

namespace json = oep::repository::json;

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

TransactionState state_from_string(const std::string& value) {
    if (value == "Committed") return TransactionState::Committed;
    if (value == "RolledBack") return TransactionState::RolledBack;
    if (value == "Failed") return TransactionState::Failed;
    return TransactionState::Opened;
}

json::Value to_json(const TransactionRecord& record) {
    json::Array entries;
    for (const JournalEntry& entry : record.entries) {
        json::Object fields;
        fields.emplace_back("timestampUtc", json::Value::string(entry.timestamp_utc));
        fields.emplace_back("operation", json::Value::string(entry.operation));
        fields.emplace_back("targetId", json::Value::string(entry.target_id));
        fields.emplace_back("previousState", json::Value::string(entry.previous_state));
        fields.emplace_back("newState", json::Value::string(entry.new_state));
        entries.push_back(json::Value::object(std::move(fields)));
    }

    json::Object fields;
    fields.emplace_back("transactionId", json::Value::string(record.transaction_id));
    fields.emplace_back("state", json::Value::string(to_string(record.state)));
    fields.emplace_back("description", json::Value::string(record.description));
    fields.emplace_back("openedUtc", json::Value::string(record.opened_utc));
    fields.emplace_back("closedUtc", json::Value::string(record.closed_utc));
    fields.emplace_back("entries", json::Value::array(std::move(entries)));
    return json::Value::object(std::move(fields));
}

struct ParsedRecord {
    bool success = false;
    std::string error;
    TransactionRecord record;
};

ParsedRecord read_record_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", {}};
    }
    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();

    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success) {
        return {false, "invalid JSON in '" + path.string() + "': " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "'" + path.string() + "' must contain a JSON object", {}};
    }

    TransactionRecord record;
    record.transaction_id = read_string_field(parsed.value, "transactionId");
    record.state = state_from_string(read_string_field(parsed.value, "state"));
    record.description = read_string_field(parsed.value, "description");
    record.opened_utc = read_string_field(parsed.value, "openedUtc");
    record.closed_utc = read_string_field(parsed.value, "closedUtc");

    const json::Value* entries = parsed.value.find("entries");
    if (entries != nullptr && entries->is_array()) {
        for (const json::Value& entry_value : entries->as_array()) {
            if (!entry_value.is_object()) {
                continue;
            }
            JournalEntry entry;
            entry.timestamp_utc = read_string_field(entry_value, "timestampUtc");
            entry.operation = read_string_field(entry_value, "operation");
            entry.target_id = read_string_field(entry_value, "targetId");
            entry.previous_state = read_string_field(entry_value, "previousState");
            entry.new_state = read_string_field(entry_value, "newState");
            record.entries.push_back(std::move(entry));
        }
    }
    return {true, "", record};
}

} // namespace

std::string to_string(TransactionState state) {
    switch (state) {
        case TransactionState::Opened: return "Opened";
        case TransactionState::Committed: return "Committed";
        case TransactionState::RolledBack: return "RolledBack";
        case TransactionState::Failed: return "Failed";
    }
    return "Opened";
}

TransactionJournal::TransactionJournal(std::filesystem::path journal_root)
    : journal_root_(std::move(journal_root)) {}

std::filesystem::path TransactionJournal::path_for(const std::string& transaction_id) const {
    return journal_root_ / (transaction_id + ".json");
}

JournalWriteResult TransactionJournal::write(const TransactionRecord& record) const {
    if (record.transaction_id.empty()) {
        return {false, "cannot journal a transaction with an empty transactionId"};
    }

    std::error_code error_code;
    std::filesystem::create_directories(journal_root_, error_code);
    if (error_code) {
        return {false, "could not create '" + journal_root_.string() + "': " + error_code.message()};
    }

    const std::filesystem::path path = path_for(record.transaction_id);
    const std::string serialized = json::serialize(to_json(record));
    const std::filesystem::path temp_path = path.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing"};
        }
        file << serialized;
    }
    std::filesystem::rename(temp_path, path, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + path.string() + "': " + error_code.message()};
    }
    return {true, ""};
}

JournalListResult TransactionJournal::list() const {
    std::vector<TransactionRecord> records;

    std::error_code error_code;
    if (!std::filesystem::exists(journal_root_, error_code)) {
        return {true, "", records};
    }

    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(journal_root_, error_code)) {
        if (!entry.is_regular_file() || entry.path().extension() != ".json") {
            continue;
        }
        const ParsedRecord parsed = read_record_file(entry.path());
        if (parsed.success) {
            records.push_back(parsed.record);
        }
    }
    if (error_code) {
        return {false, "could not enumerate '" + journal_root_.string() + "': " + error_code.message(), {}};
    }

    std::sort(records.begin(), records.end(), [](const TransactionRecord& a, const TransactionRecord& b) {
        if (a.opened_utc != b.opened_utc) return a.opened_utc < b.opened_utc;
        return a.transaction_id < b.transaction_id;
    });
    return {true, "", records};
}

JournalLoadResult TransactionJournal::load(const std::string& transaction_id) const {
    const std::filesystem::path path = path_for(transaction_id);
    std::error_code error_code;
    if (!std::filesystem::exists(path, error_code)) {
        return {false, "no journaled transaction with id '" + transaction_id + "'", {}};
    }
    const ParsedRecord parsed = read_record_file(path);
    if (!parsed.success) {
        return {false, parsed.error, {}};
    }
    return {true, "", parsed.record};
}

} // namespace oep::runtime

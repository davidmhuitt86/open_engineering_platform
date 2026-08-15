#include "oep/repository/audit_store.hpp"

#include <algorithm>
#include <fstream>
#include <sstream>
#include <system_error>

#include "oep/repository/json_value.hpp"
#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

namespace oep::repository {

namespace {

std::string join_errors(const std::vector<std::string>& errors) {
    std::string message;
    for (std::size_t i = 0; i < errors.size(); ++i) {
        message += errors[i];
        if (i + 1 != errors.size()) message += "; ";
    }
    return message;
}

json::Value to_json(const AuditEvent& event) {
    json::Object fields;
    fields.emplace_back("eventId", json::Value::string(event.event_id));
    fields.emplace_back("timestampUtc", json::Value::string(event.timestamp_utc));
    fields.emplace_back("eventType", json::Value::string(to_string(event.event_type)));
    fields.emplace_back("objectId", json::Value::string(event.object_id));
    fields.emplace_back("user", json::Value::string(event.user));
    fields.emplace_back("description", json::Value::string(event.description));
    return json::Value::object(std::move(fields));
}

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

struct ParsedEvent {
    bool success = false;
    std::string error;
    AuditEvent event;
};

ParsedEvent read_event_file(const std::filesystem::path& path) {
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

    AuditEvent event;
    event.event_id = read_string_field(parsed.value, "eventId");
    event.timestamp_utc = read_string_field(parsed.value, "timestampUtc");

    const std::string type_name = read_string_field(parsed.value, "eventType");
    const std::optional<AuditEventType> type = audit_event_type_from_string(type_name);
    if (!type.has_value()) {
        return {false, "'" + path.string() + "' has an unrecognized eventType '" + type_name + "'", {}};
    }
    event.event_type = *type;

    event.object_id = read_string_field(parsed.value, "objectId");
    event.user = read_string_field(parsed.value, "user");
    event.description = read_string_field(parsed.value, "description");

    return {true, "", event};
}

AuditResult write_event_file(const std::filesystem::path& path, const AuditEvent& event) {
    const std::string serialized = json::serialize(to_json(event));

    const std::filesystem::path temp_path = path.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing"};
        }
        file << serialized;
    }

    std::error_code error_code;
    std::filesystem::rename(temp_path, path, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + path.string() + "': " + error_code.message()};
    }

    return {true, ""};
}

bool event_less(const AuditEvent& a, const AuditEvent& b) {
    if (a.timestamp_utc != b.timestamp_utc) return a.timestamp_utc < b.timestamp_utc;
    return a.event_id < b.event_id;
}

} // namespace

AuditStore::AuditStore(std::filesystem::path root) : root_(std::move(root)) {}

std::filesystem::path AuditStore::path_for(const std::string& event_id) const {
    return root_ / (event_id + ".json");
}

RecordEventResult AuditStore::record_event(AuditEvent event) const {
    if (event.event_id.empty()) {
        event.event_id = generate_uuid_v4();
    }
    if (event.timestamp_utc.empty()) {
        event.timestamp_utc = current_timestamp_utc();
    }

    const std::vector<std::string> errors = validate_audit_event(event);
    if (!errors.empty()) {
        return {false, "refusing to record invalid audit event: " + join_errors(errors), {}};
    }

    std::error_code error_code;
    std::filesystem::create_directories(root_, error_code);
    if (error_code) {
        return {false, "could not create '" + root_.string() + "': " + error_code.message(), {}};
    }

    const std::filesystem::path path = path_for(event.event_id);
    if (std::filesystem::exists(path)) {
        return {false, "an audit event with id '" + event.event_id + "' already exists", {}};
    }

    const AuditResult write_result = write_event_file(path, event);
    if (!write_result.success) {
        return {false, write_result.error, {}};
    }

    return {true, "", event};
}

RecordEventResult AuditStore::restore(AuditEvent event) const {
    const std::vector<std::string> errors = validate_audit_event(event);
    if (!errors.empty()) {
        return {false, "refusing to restore invalid audit event: " + join_errors(errors), {}};
    }

    std::error_code error_code;
    std::filesystem::create_directories(root_, error_code);
    if (error_code) {
        return {false, "could not create '" + root_.string() + "': " + error_code.message(), {}};
    }

    const std::filesystem::path path = path_for(event.event_id);
    if (std::filesystem::exists(path)) {
        return {false, "an audit event with id '" + event.event_id + "' already exists", {}};
    }

    const AuditResult write_result = write_event_file(path, event);
    if (!write_result.success) {
        return {false, write_result.error, {}};
    }

    return {true, "", event};
}

ListAuditEventsResult AuditStore::list_events() const {
    std::vector<AuditEvent> events;

    std::error_code error_code;
    if (!std::filesystem::exists(root_, error_code)) {
        return {true, "", events};
    }

    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(root_, error_code)) {
        if (!entry.is_regular_file() || entry.path().extension() != ".json") {
            continue;
        }
        const ParsedEvent parsed = read_event_file(entry.path());
        if (!parsed.success) {
            continue; // skip files that are not valid audit events
        }
        events.push_back(parsed.event);
    }

    if (error_code) {
        return {false, "could not enumerate '" + root_.string() + "': " + error_code.message(), {}};
    }

    std::sort(events.begin(), events.end(), event_less);
    return {true, "", events};
}

ListAuditEventsResult AuditStore::list_events_for_object(const std::string& object_id) const {
    const ListAuditEventsResult all = list_events();
    if (!all.success) {
        return all;
    }

    std::vector<AuditEvent> matching;
    for (const AuditEvent& event : all.events) {
        if (event.object_id == object_id) {
            matching.push_back(event);
        }
    }

    return {true, "", matching};
}

AuditResult AuditStore::clear() const {
    std::error_code error_code;
    if (!std::filesystem::exists(root_, error_code)) {
        return {true, ""};
    }

    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(root_, error_code)) {
        if (entry.is_regular_file() && entry.path().extension() == ".json") {
            std::filesystem::remove(entry.path(), error_code);
        }
    }

    if (error_code) {
        return {false, "could not clear '" + root_.string() + "': " + error_code.message()};
    }

    return {true, ""};
}

} // namespace oep::repository

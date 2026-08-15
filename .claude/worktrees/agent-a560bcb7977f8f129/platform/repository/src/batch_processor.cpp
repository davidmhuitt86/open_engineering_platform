#include "oep/repository/batch_processor.hpp"

#include <map>
#include <set>

#include "oep/repository/json_value.hpp"

namespace oep::repository {

namespace {

std::string read_string(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

std::vector<std::string> read_string_array(const json::Value& value, const char* key) {
    std::vector<std::string> result;
    const json::Value* found = value.find(key);
    if (found == nullptr || !found->is_array()) return result;
    for (const json::Value& entry : found->as_array()) {
        if (entry.is_string()) result.push_back(entry.as_string());
    }
    return result;
}

std::string join_errors(const std::vector<std::string>& errors) {
    std::string message;
    for (std::size_t i = 0; i < errors.size(); ++i) {
        message += errors[i];
        if (i + 1 != errors.size()) message += "; ";
    }
    return message;
}

std::string describe_object(const BatchObjectSpec& spec, std::size_t index) {
    return spec.ref.empty() ? ("objects[" + std::to_string(index) + "]") : ("'" + spec.ref + "'");
}

} // namespace

BatchParseResult parse_batch_create_request(const std::string& json_text) {
    const json::ParseResult parsed = json::parse(json_text);
    if (!parsed.success) {
        return {false, "invalid JSON: " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "batch input must be a JSON object", {}};
    }

    BatchCreateRequest request;

    if (const json::Value* objects_value = parsed.value.find("objects");
        objects_value != nullptr && objects_value->is_array()) {
        for (const json::Value& entry : objects_value->as_array()) {
            BatchObjectSpec spec;
            spec.ref = read_string(entry, "ref");
            const std::string type_name = read_string(entry, "type");
            const auto type = object_type_from_string(type_name);
            if (!type.has_value()) {
                return {false, "unrecognized object type '" + type_name + "'", {}};
            }
            spec.object_type = *type;
            spec.name = read_string(entry, "name");
            spec.description = read_string(entry, "description");
            spec.author = read_string(entry, "author");
            spec.tags = read_string_array(entry, "tags");
            request.objects.push_back(std::move(spec));
        }
    }

    if (const json::Value* relationships_value = parsed.value.find("relationships");
        relationships_value != nullptr && relationships_value->is_array()) {
        for (const json::Value& entry : relationships_value->as_array()) {
            BatchRelationshipSpec spec;
            spec.source = read_string(entry, "source");
            spec.target = read_string(entry, "target");
            const std::string type_name = read_string(entry, "type");
            const auto type = relationship_type_from_string(type_name);
            if (!type.has_value()) {
                return {false, "unrecognized relationship type '" + type_name + "'", {}};
            }
            spec.relationship_type = *type;
            spec.author = read_string(entry, "author");
            spec.description = read_string(entry, "description");
            request.relationships.push_back(std::move(spec));
        }
    }

    return {true, "", request};
}

BatchDeleteParseResult parse_batch_delete_request(const std::string& json_text) {
    const json::ParseResult parsed = json::parse(json_text);
    if (!parsed.success) {
        return {false, "invalid JSON: " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "batch input must be a JSON object", {}};
    }

    BatchDeleteRequest request;
    request.object_ids = read_string_array(parsed.value, "objectIds");
    request.relationship_ids = read_string_array(parsed.value, "relationshipIds");
    return {true, "", request};
}

std::vector<std::string> validate_batch_create_request(const BatchCreateRequest& request,
                                                        const ObjectStore& objects) {
    std::vector<std::string> errors;

    std::set<std::string> seen_refs;
    std::set<std::string> known_refs;
    for (const BatchObjectSpec& spec : request.objects) {
        if (!spec.ref.empty()) {
            known_refs.insert(spec.ref);
        }
    }

    for (std::size_t i = 0; i < request.objects.size(); ++i) {
        const BatchObjectSpec& spec = request.objects[i];
        if (!spec.ref.empty() && !seen_refs.insert(spec.ref).second) {
            errors.push_back("duplicate ref '" + spec.ref + "'");
        }
        if (spec.name.empty()) {
            errors.push_back(describe_object(spec, i) + " is missing a name");
        }
    }

    for (std::size_t i = 0; i < request.relationships.size(); ++i) {
        const BatchRelationshipSpec& spec = request.relationships[i];
        const std::string label = "relationships[" + std::to_string(i) + "]";

        const bool source_is_ref = known_refs.count(spec.source) != 0;
        const bool target_is_ref = known_refs.count(spec.target) != 0;

        if (spec.source.empty()) {
            errors.push_back(label + " is missing a source");
        } else if (!source_is_ref && !objects.load(spec.source).success) {
            errors.push_back(label + " references unknown source '" + spec.source + "'");
        }

        if (spec.target.empty()) {
            errors.push_back(label + " is missing a target");
        } else if (!target_is_ref && !objects.load(spec.target).success) {
            errors.push_back(label + " references unknown target '" + spec.target + "'");
        }

        if (!spec.source.empty() && spec.source == spec.target) {
            errors.push_back(label + " has matching source and target ('" + spec.source + "')");
        }
    }

    return errors;
}

BatchCreateResult execute_batch_create(const BatchCreateRequest& request, const ObjectStore& objects,
                                       const RelationshipStore& relationships) {
    const std::vector<std::string> errors = validate_batch_create_request(request, objects);
    if (!errors.empty()) {
        return {false, "batch validation failed: " + join_errors(errors), 0, 0};
    }

    std::map<std::string, std::string> ref_to_object_id;
    int objects_created = 0;

    for (const BatchObjectSpec& spec : request.objects) {
        EngineeringObject object;
        object.object_type = spec.object_type;
        object.name = spec.name;
        object.description = spec.description;
        object.author = spec.author;
        object.tags = spec.tags;

        const LoadObjectResult result = objects.create(object);
        if (!result.success) {
            return {false, "failed creating object '" + spec.name + "': " + result.error, objects_created, 0};
        }
        ++objects_created;
        if (!spec.ref.empty()) {
            ref_to_object_id[spec.ref] = result.object.object_id;
        }
    }

    int relationships_created = 0;
    for (const BatchRelationshipSpec& spec : request.relationships) {
        Relationship relationship;
        const auto source_it = ref_to_object_id.find(spec.source);
        relationship.source_object_id = source_it != ref_to_object_id.end() ? source_it->second : spec.source;
        const auto target_it = ref_to_object_id.find(spec.target);
        relationship.target_object_id = target_it != ref_to_object_id.end() ? target_it->second : spec.target;
        relationship.relationship_type = spec.relationship_type;
        relationship.author = spec.author;
        relationship.description = spec.description;

        const LoadRelationshipResult result = relationships.create(relationship);
        if (!result.success) {
            return {false, "failed creating relationship: " + result.error, objects_created, relationships_created};
        }
        ++relationships_created;
    }

    return {true, "", objects_created, relationships_created};
}

BatchDeleteResult execute_batch_delete(const BatchDeleteRequest& request, const ObjectStore& objects,
                                       const RelationshipStore& relationships) {
    std::vector<std::string> errors;
    for (const std::string& object_id : request.object_ids) {
        if (!objects.load(object_id).success) {
            errors.push_back("no object with id '" + object_id + "'");
        }
    }
    for (const std::string& relationship_id : request.relationship_ids) {
        if (!relationships.load(relationship_id).success) {
            errors.push_back("no relationship with id '" + relationship_id + "'");
        }
    }
    if (!errors.empty()) {
        return {false, "batch validation failed: " + join_errors(errors), 0, 0};
    }

    int relationships_deleted = 0;
    for (const std::string& relationship_id : request.relationship_ids) {
        const RelationshipResult result = relationships.remove(relationship_id);
        if (!result.success) {
            return {false, "failed deleting relationship '" + relationship_id + "': " + result.error, 0,
                    relationships_deleted};
        }
        ++relationships_deleted;
    }

    int objects_deleted = 0;
    for (const std::string& object_id : request.object_ids) {
        const ObjectResult result = objects.remove(object_id);
        if (!result.success) {
            return {false, "failed deleting object '" + object_id + "': " + result.error, objects_deleted,
                    relationships_deleted};
        }
        ++objects_deleted;
    }

    return {true, "", objects_deleted, relationships_deleted};
}

} // namespace oep::repository

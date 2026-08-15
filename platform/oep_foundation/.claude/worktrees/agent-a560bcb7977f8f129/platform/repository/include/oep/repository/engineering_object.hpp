#pragma once

#include <optional>
#include <string>
#include <vector>

namespace oep::repository {

// Initial Engineering Object classification, per OEP-SPEC-004-ENGINEERING_OBJECT_MODEL.
enum class ObjectType {
    Document,
    Diagram,
    Component,
    Procedure,
    Project,
    Image,
};

std::string to_string(ObjectType type);
std::optional<ObjectType> object_type_from_string(const std::string& value);

// An Engineering Object: the fundamental unit of engineering knowledge
// stored within an OEP repository. The object_id is permanent and never
// changes for the lifetime of the object.
struct EngineeringObject {
    std::string object_id;
    ObjectType object_type = ObjectType::Document;
    std::string name;
    std::string description;
    std::string created_utc;
    std::string last_modified_utc;
    std::string version = "1.0.0";
    std::string author;
    std::vector<std::string> tags;
};

// Validates required fields, object_id's UUIDv4 format, and version's
// semantic-version format. Returns a human-readable error per violation
// found; an empty result means `object` is valid.
std::vector<std::string> validate_object(const EngineeringObject& object);

} // namespace oep::repository

#pragma once

#include <optional>
#include <string>
#include <vector>

namespace oep::repository {

// Initial relationship classification, per OEP-SPEC-005-OBJECT_RELATIONSHIP_MODEL.
enum class RelationshipType {
    References,
    Contains,
    DependsOn,
    ConnectedTo,
    Documents,
    Implements,
};

std::string to_string(RelationshipType type);
std::optional<RelationshipType> relationship_type_from_string(const std::string& value);

// A directional edge connecting two Engineering Objects. source_object_id
// is the origin of the relationship; target_object_id is the destination.
struct Relationship {
    std::string relationship_id;
    std::string source_object_id;
    std::string target_object_id;
    RelationshipType relationship_type = RelationshipType::References;
    std::string created_utc;
    std::string author;
    std::string description;

    // AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — same field, same meaning,
    // same referential-integrity story as EngineeringObject::diagram_id
    // (see that field's own doc comment for the full rationale). Empty
    // for every relationship that predates this field or belongs to no
    // diagram/graph.
    std::string diagram_id;
};

// Validates required fields, UUIDv4 format for all identifiers, and that
// source_object_id differs from target_object_id. Does not verify that
// the referenced objects exist — see RelationshipStore::create for that.
std::vector<std::string> validate_relationship(const Relationship& relationship);

} // namespace oep::repository

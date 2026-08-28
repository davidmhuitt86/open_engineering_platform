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

    // Opaque, application-owned payload (AP-DS-002, OEP-SPEC-004
    // amendment). Foundation never parses or interprets this field — it
    // exists so a consuming application (e.g. Diagram Studio) can persist
    // presentation-layer state that has no independent engineering
    // meaning of its own (layout positions, viewport, selection state)
    // alongside the object it describes, without inventing a new
    // primitive or duplicating the object elsewhere. Empty for every
    // object that predates this field or has no such payload.
    std::string content;

    // AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — the object_id of the
    // ObjectType::Diagram-category Engineering Object this object is a
    // member of, or empty if it belongs to no diagram/graph (the
    // default, and the state of every object that predates this field).
    // Deliberately named `diagram_id`, not `graph_id`: this repository
    // already has an unrelated, whole-repository, never-persisted
    // traversal concept called a "graph" (`GraphEngine`,
    // OEP-SPEC-007-GRAPH_TRAVERSAL.md) — reusing that word here for a
    // *persisted, named subset* of objects/relationships would collide
    // with it in name only, not in meaning. No new primitive is
    // introduced: a "diagram" is an ordinary Engineering Object
    // (ObjectType::Diagram already existed), and this field is exactly
    // the same shape/precedent as `content` above — an additive,
    // backward-compatible attribute on the existing Engineering Object
    // primitive, not a sixth primitive type (CLAUDE.md's Five Primitive
    // Rule). Referential integrity (this value, when non-empty, always
    // names a real, existing ObjectType::Diagram object) is enforced by
    // the API layer at creation time (`oep_object_create_with_diagram`),
    // not by this struct — Foundation does not currently cascade-check
    // relationship endpoints against object existence either
    // (`RelationshipStore::create`), so this follows that same,
    // pre-existing convention rather than inventing new referential
    // enforcement machinery elsewhere in this task.
    std::string diagram_id;
};

// Validates required fields, object_id's UUIDv4 format, and version's
// semantic-version format. Returns a human-readable error per violation
// found; an empty result means `object` is valid.
std::vector<std::string> validate_object(const EngineeringObject& object);

} // namespace oep::repository

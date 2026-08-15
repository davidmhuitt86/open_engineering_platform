#pragma once

#include <filesystem>

#include "oep/repository/audit_store.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"
#include "oep/validation/validation_result.hpp"

namespace oep::validation {

// Read-only integrity validation over a repository's metadata,
// Engineering Objects, and Relationships, per
// OEP-SPEC-009-REPOSITORY_VALIDATION. Never modifies repository
// contents and never creates temporary files; operates entirely in
// memory. Every check continues past individual failures, so a single
// report reflects every integrity problem found, not just the first.
class RepositoryValidator {
public:
    RepositoryValidator(std::filesystem::path metadata_path, oep::repository::ObjectStore objects,
                         oep::repository::RelationshipStore relationships, oep::repository::AuditStore audit);

    // Checks that repository.json exists, parses, and passes its own
    // schema validation (including that the repository ID is a valid UUIDv4).
    std::vector<ValidationFinding> validate_metadata() const;

    // Checks that every stored object parses (surfacing invalid object
    // types as findings) and that no two objects share an object ID.
    std::vector<ValidationFinding> validate_objects() const;

    // Checks that every stored relationship parses (surfacing invalid
    // relationship types as findings), that no two relationships share a
    // relationship ID, and that every relationship's source and target
    // objects exist.
    std::vector<ValidationFinding> validate_relationships() const;

    // Runs every check above, plus cross-cutting checks (no UUID reused
    // across objects and relationships; audit events reference an
    // existing object/relationship when the event type implies one
    // should still exist), and produces a complete, deterministic report.
    ValidationReport validate_repository() const;

private:
    std::filesystem::path metadata_path_;
    oep::repository::ObjectStore objects_;
    oep::repository::RelationshipStore relationships_;
    oep::repository::AuditStore audit_;
};

} // namespace oep::validation

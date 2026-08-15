#pragma once

#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

namespace oep::repository {

// One object to create as part of a batch. `ref` is a batch-local
// alias (not a real object ID) that a BatchRelationshipSpec in the
// same batch may use as its source/target.
struct BatchObjectSpec {
    std::string ref;
    ObjectType object_type = ObjectType::Document;
    std::string name;
    std::string description;
    std::string author;
    std::vector<std::string> tags;
};

// One relationship to create as part of a batch. `source`/`target`
// are resolved first against this batch's object `ref`s, then — if
// no match — treated as an existing object's real ID.
struct BatchRelationshipSpec {
    std::string source;
    std::string target;
    RelationshipType relationship_type = RelationshipType::References;
    std::string author;
    std::string description;
};

struct BatchCreateRequest {
    std::vector<BatchObjectSpec> objects;
    std::vector<BatchRelationshipSpec> relationships;
};

struct BatchDeleteRequest {
    std::vector<std::string> object_ids;
    std::vector<std::string> relationship_ids;
};

struct BatchParseResult {
    bool success = false;
    std::string error;
    BatchCreateRequest request;
};

// Parses the batch-create JSON input format documented in
// platform/runtime/CLI_USAGE.md. Fails for malformed JSON or an
// unrecognized objectType/relationshipType; does not check for
// duplicate refs or unresolvable source/target — that is
// validate_batch_create_request's job, since it additionally needs
// the target ObjectStore.
BatchParseResult parse_batch_create_request(const std::string& json_text);

struct BatchDeleteParseResult {
    bool success = false;
    std::string error;
    BatchDeleteRequest request;
};

BatchDeleteParseResult parse_batch_delete_request(const std::string& json_text);

// Validates `request` structurally (duplicate refs, missing required
// fields) and against `objects` (every source/target resolves to
// either an in-batch ref or an existing object; source != target).
// Returns one message per problem found; empty means valid. Never
// modifies the repository.
std::vector<std::string> validate_batch_create_request(const BatchCreateRequest& request, const ObjectStore& objects);

struct BatchCreateResult {
    bool success = false;
    std::string error;
    int objects_created = 0;
    int relationships_created = 0;
};

// Fully validates `request` (via validate_batch_create_request) before
// creating anything; a validation failure creates nothing. On
// success, creates every object first, then every relationship,
// resolving `ref`s to the newly created objects' real IDs.
BatchCreateResult execute_batch_create(const BatchCreateRequest& request, const ObjectStore& objects,
                                       const RelationshipStore& relationships);

struct BatchDeleteResult {
    bool success = false;
    std::string error;
    int objects_deleted = 0;
    int relationships_deleted = 0;
};

// Fully validates that every referenced object/relationship ID exists
// before deleting anything.
BatchDeleteResult execute_batch_delete(const BatchDeleteRequest& request, const ObjectStore& objects,
                                       const RelationshipStore& relationships);

} // namespace oep::repository

#pragma once

#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

namespace oep::search {

// The field a query matched against, per OEP-SPEC-006-REPOSITORY_SEARCH.
enum class MatchLocation {
    Name,
    Description,
    Author,
    Tags,
    ObjectType,
    RelationshipType,
};

std::string to_string(MatchLocation location);

struct ObjectSearchResult {
    std::string object_id;
    oep::repository::ObjectType object_type;
    std::string display_name;
    MatchLocation match_location;
    double match_score = 0.0;
};

struct RelationshipSearchResult {
    std::string relationship_id;
    std::string source_object_id;
    std::string target_object_id;
    oep::repository::RelationshipType relationship_type;
    MatchLocation match_location;
    double match_score = 0.0;
};

struct SearchObjectsResult {
    bool success = false;
    std::string error;
    std::vector<ObjectSearchResult> results;
};

struct SearchRelationshipsResult {
    bool success = false;
    std::string error;
    std::vector<RelationshipSearchResult> results;
};

// An in-memory, offline search index over a repository's Engineering
// Objects and Relationships, per OEP-SPEC-006-REPOSITORY_SEARCH. The
// index is never persisted; call build_index whenever the repository
// is loaded (or has changed) to refresh it. Never modifies repository
// contents.
class SearchEngine {
public:
    // Replaces the current index with everything currently stored in
    // `objects` and `relationships`.
    void build_index(const oep::repository::ObjectStore& objects,
                      const oep::repository::RelationshipStore& relationships);

    void clear_index();

    // Case-insensitive, partial-match search across name, description,
    // author, tags, and object type. Results are sorted by descending
    // match score, then by index order, so identical repository state
    // and query always produce identical results. Fails only for a
    // structurally invalid query (currently: empty query text).
    SearchObjectsResult search_objects(const std::string& query) const;

    // Case-insensitive, partial-match search across relationship type,
    // description, and author.
    SearchRelationshipsResult search_relationships(const std::string& query) const;

private:
    std::vector<oep::repository::EngineeringObject> indexed_objects_;
    std::vector<oep::repository::Relationship> indexed_relationships_;
};

} // namespace oep::search

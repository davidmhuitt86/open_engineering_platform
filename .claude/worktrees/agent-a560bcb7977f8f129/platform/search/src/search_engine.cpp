#include "oep/search/search_engine.hpp"

#include <algorithm>
#include <cctype>

namespace oep::search {

namespace {

std::string to_lower(const std::string& value) {
    std::string result = value;
    std::transform(result.begin(), result.end(), result.begin(),
                    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return result;
}

// Returns a match score for `field` against `query_lower` (already
// lowercased), or -1.0 if there is no match.
double score_field(const std::string& field, const std::string& query_lower) {
    const std::string field_lower = to_lower(field);
    if (field_lower == query_lower) {
        return 1.0;
    }
    if (field_lower.find(query_lower) != std::string::npos) {
        return 0.5;
    }
    return -1.0;
}

double score_tags(const std::vector<std::string>& tags, const std::string& query_lower) {
    double best = -1.0;
    for (const std::string& tag : tags) {
        best = std::max(best, score_field(tag, query_lower));
    }
    return best;
}

struct Candidate {
    MatchLocation location;
    double score;
};

// Returns the first candidate (in priority order) with a non-negative
// score, or nullptr if nothing matched.
const Candidate* best_candidate(const std::vector<Candidate>& candidates) {
    for (const Candidate& candidate : candidates) {
        if (candidate.score >= 0.0) {
            return &candidate;
        }
    }
    return nullptr;
}

} // namespace

std::string to_string(MatchLocation location) {
    switch (location) {
        case MatchLocation::Name: return "Name";
        case MatchLocation::Description: return "Description";
        case MatchLocation::Author: return "Author";
        case MatchLocation::Tags: return "Tags";
        case MatchLocation::ObjectType: return "ObjectType";
        case MatchLocation::RelationshipType: return "RelationshipType";
    }
    return "Name";
}

void SearchEngine::build_index(const oep::repository::ObjectStore& objects,
                                const oep::repository::RelationshipStore& relationships) {
    indexed_objects_.clear();
    indexed_relationships_.clear();

    const oep::repository::ListObjectsResult object_result = objects.list_all();
    if (object_result.success) {
        indexed_objects_ = object_result.objects;
    }

    const oep::repository::ListRelationshipsResult relationship_result = relationships.list_all();
    if (relationship_result.success) {
        indexed_relationships_ = relationship_result.relationships;
    }
}

void SearchEngine::clear_index() {
    indexed_objects_.clear();
    indexed_relationships_.clear();
}

SearchObjectsResult SearchEngine::search_objects(const std::string& query) const {
    if (query.empty()) {
        return {false, "search query must not be empty", {}};
    }

    const std::string query_lower = to_lower(query);
    std::vector<ObjectSearchResult> results;

    for (const oep::repository::EngineeringObject& object : indexed_objects_) {
        const std::vector<Candidate> candidates = {
            {MatchLocation::Name, score_field(object.name, query_lower)},
            {MatchLocation::Description, score_field(object.description, query_lower)},
            {MatchLocation::Author, score_field(object.author, query_lower)},
            {MatchLocation::Tags, score_tags(object.tags, query_lower)},
            {MatchLocation::ObjectType, score_field(oep::repository::to_string(object.object_type), query_lower)},
        };

        if (const Candidate* match = best_candidate(candidates)) {
            results.push_back(
                {object.object_id, object.object_type, object.name, match->location, match->score});
        }
    }

    std::stable_sort(results.begin(), results.end(),
                      [](const ObjectSearchResult& a, const ObjectSearchResult& b) {
                          return a.match_score > b.match_score;
                      });

    return {true, "", results};
}

SearchRelationshipsResult SearchEngine::search_relationships(const std::string& query) const {
    if (query.empty()) {
        return {false, "search query must not be empty", {}};
    }

    const std::string query_lower = to_lower(query);
    std::vector<RelationshipSearchResult> results;

    for (const oep::repository::Relationship& relationship : indexed_relationships_) {
        const std::vector<Candidate> candidates = {
            {MatchLocation::RelationshipType,
             score_field(oep::repository::to_string(relationship.relationship_type), query_lower)},
            {MatchLocation::Description, score_field(relationship.description, query_lower)},
            {MatchLocation::Author, score_field(relationship.author, query_lower)},
        };

        if (const Candidate* match = best_candidate(candidates)) {
            results.push_back({relationship.relationship_id, relationship.source_object_id,
                                relationship.target_object_id, relationship.relationship_type,
                                match->location, match->score});
        }
    }

    std::stable_sort(results.begin(), results.end(),
                      [](const RelationshipSearchResult& a, const RelationshipSearchResult& b) {
                          return a.match_score > b.match_score;
                      });

    return {true, "", results};
}

} // namespace oep::search

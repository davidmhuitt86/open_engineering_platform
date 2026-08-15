#include "oep/search/search_engine.hpp"

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

#include <filesystem>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

oep::repository::EngineeringObject make_object(oep::repository::ObjectType type, const std::string& name,
                                                 const std::string& description, const std::string& author,
                                                 std::vector<std::string> tags) {
    oep::repository::EngineeringObject object;
    object.object_type = type;
    object.name = name;
    object.description = description;
    object.author = author;
    object.tags = std::move(tags);
    object.version = "1.0.0";
    return object;
}

bool contains_object(const std::vector<oep::search::ObjectSearchResult>& results, const std::string& object_id) {
    for (const oep::search::ObjectSearchResult& result : results) {
        if (result.object_id == object_id) return true;
    }
    return false;
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_search_engine_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    const oep::repository::ObjectStore objects(scratch_dir / "objects",
                                                oep::repository::AuditStore(scratch_dir / "audit"));
    const oep::repository::RelationshipStore relationships(
        scratch_dir / "relationships", objects, oep::repository::AuditStore(scratch_dir / "audit"));

    const oep::repository::LoadObjectResult coil =
        objects.create(make_object(oep::repository::ObjectType::Component, "Ignition Coil",
                                    "Generates spark for combustion", "Jane Engineer", {"electrical", "ignition"}));
    const oep::repository::LoadObjectResult manual =
        objects.create(make_object(oep::repository::ObjectType::Document, "Service Manual",
                                    "Full service documentation", "John Author", {"reference"}));
    check(coil.success && manual.success, "creating sample objects succeeds");

    oep::repository::Relationship documents;
    documents.source_object_id = manual.object.object_id;
    documents.target_object_id = coil.object.object_id;
    documents.relationship_type = oep::repository::RelationshipType::Documents;
    documents.author = "Jane Engineer";
    documents.description = "Manual documents the coil";
    check(relationships.create(documents).success, "creating the sample relationship succeeds");

    oep::search::SearchEngine engine;

    // Missing index (never built) is handled gracefully: no crash, empty results.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("coil");
        check(result.success, "search_objects succeeds even before build_index is called");
        check(result.results.empty(), "search_objects finds nothing before build_index is called");
    }

    engine.build_index(objects, relationships);

    // Exact, case-insensitive name match.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("IGNITION COIL");
        check(result.success, "search_objects succeeds for an exact name query");
        check(contains_object(result.results, coil.object.object_id), "exact name search finds the coil");
        check(!result.results.empty() && result.results.front().match_location == oep::search::MatchLocation::Name,
              "exact name match reports MatchLocation::Name");
        check(!result.results.empty() && result.results.front().match_score == 1.0,
              "exact name match scores 1.0");
    }

    // Partial, case-insensitive description match.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("combustion");
        check(result.success, "search_objects succeeds for a partial description query");
        check(contains_object(result.results, coil.object.object_id), "partial description search finds the coil");
    }

    // Author match.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("john author");
        check(contains_object(result.results, manual.object.object_id), "author search finds the manual");
    }

    // Tag match.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("ignition");
        check(contains_object(result.results, coil.object.object_id), "tag search finds the coil");
    }

    // Object type match.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("document");
        check(contains_object(result.results, manual.object.object_id), "object type search finds the manual");
    }

    // Relationship type / description / author search.
    {
        const oep::search::SearchRelationshipsResult by_type = engine.search_relationships("documents");
        check(by_type.success && !by_type.results.empty(), "relationship search finds a match by type");

        const oep::search::SearchRelationshipsResult by_description = engine.search_relationships("documents the coil");
        check(!by_description.results.empty(), "relationship search finds a match by description");

        const oep::search::SearchRelationshipsResult by_author = engine.search_relationships("jane engineer");
        check(!by_author.results.empty(), "relationship search finds a match by author");
        check(by_author.results.front().source_object_id == manual.object.object_id,
              "relationship result identifies the source object");
        check(by_author.results.front().target_object_id == coil.object.object_id,
              "relationship result identifies the target object");
    }

    // No match.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("nonexistent-term-xyz");
        check(result.success, "search_objects succeeds even with no matches");
        check(result.results.empty(), "search_objects returns no results for an unmatched query");
    }

    // Invalid query (empty string) is handled gracefully.
    {
        const oep::search::SearchObjectsResult result = engine.search_objects("");
        check(!result.success, "search_objects rejects an empty query");
        check(!result.error.empty(), "search_objects reports a descriptive error for an empty query");
    }

    // Determinism: repeated identical queries against unchanged state return identical results.
    {
        const oep::search::SearchObjectsResult first = engine.search_objects("coil");
        const oep::search::SearchObjectsResult second = engine.search_objects("coil");
        check(first.success && second.success && first.results.size() == second.results.size(),
              "repeated searches over unchanged state return the same number of results");
    }

    // Rebuilding after removing an object drops it from the index.
    {
        check(objects.remove(coil.object.object_id).success, "removing the coil object succeeds");
        engine.build_index(objects, relationships);
        const oep::search::SearchObjectsResult result = engine.search_objects("ignition coil");
        check(!contains_object(result.results, coil.object.object_id),
              "rebuilding the index after removal no longer finds the removed object");
    }

    // clear_index empties the index without touching repository contents.
    {
        engine.clear_index();
        const oep::search::SearchObjectsResult result = engine.search_objects("manual");
        check(result.success && result.results.empty(), "clear_index empties the in-memory index");

        const oep::repository::LoadObjectResult reloaded = objects.load(manual.object.object_id);
        check(reloaded.success, "clear_index does not modify repository contents");
    }

    // Empty repository builds an empty, valid index.
    {
        const std::filesystem::path empty_dir = scratch_dir / "empty";
        const oep::repository::ObjectStore empty_objects(empty_dir / "objects",
                                                          oep::repository::AuditStore(empty_dir / "audit"));
        const oep::repository::RelationshipStore empty_relationships(
            empty_dir / "relationships", empty_objects, oep::repository::AuditStore(empty_dir / "audit"));

        oep::search::SearchEngine empty_engine;
        empty_engine.build_index(empty_objects, empty_relationships);

        const oep::search::SearchObjectsResult result = empty_engine.search_objects("anything");
        check(result.success && result.results.empty(), "build_index handles an empty repository gracefully");
    }

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All search engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " search engine test(s) failed.\n";
    return 1;
}

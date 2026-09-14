#include <catch2/catch_test_macros.hpp>

#include <httplib.h>
#include <nlohmann/json.hpp>
#include <pqxx/pqxx>

#include "oep/server_repository/api/server.hpp"
#include "oep/server_repository/common/uuid.hpp"
#include "oep/server_repository/persistence/store.hpp"
#include "test_support.hpp"

using oep::server_repository::api::ApiServer;
using oep::server_repository::common::ServerConfig;
using oep::server_repository::common::generate_uuid_v4;
using oep::server_repository::persistence::ServerRepositoryStore;
using oep::server_repository::test_support::kTestApiToken;
using oep::server_repository::test_support::reset_schema;
using oep::server_repository::test_support::test_database_config;

namespace {

nlohmann::json object_create_mutation(const std::string& object_id, const std::string& name) {
  return nlohmann::json{
      {"kind", "object_create"},
      {"object_id", object_id},
      {"object", nlohmann::json{{"object_type", "document"}, {"name", name}, {"description", "test object"},
                                   {"author", "wp-srv-012"}, {"tags", nlohmann::json::array({"a", "b"})},
                                   {"content", "hello"}, {"version", "1.0.0"}}},
  };
}

nlohmann::json object_update_mutation(const std::string& object_id, std::int64_t expected_revision,
                                        const std::string& name) {
  return nlohmann::json{
      {"kind", "object_update"},
      {"object_id", object_id},
      {"expected_revision", expected_revision},
      {"object", nlohmann::json{{"object_type", "document"}, {"name", name}, {"description", "updated"},
                                   {"author", "wp-srv-012"}, {"tags", nlohmann::json::array()},
                                   {"content", "updated"}, {"version", "1.0.1"}}},
  };
}

// WP-SRV-012 / ADR-0006 SS10 SS101: a delete mutation carries only the
// identity + expected_revision -- no nested "object" body.
nlohmann::json object_delete_mutation(const std::string& object_id, std::int64_t expected_revision) {
  return nlohmann::json{
      {"kind", "object_delete"},
      {"object_id", object_id},
      {"expected_revision", expected_revision},
  };
}

nlohmann::json relationship_create_mutation(const std::string& relationship_id, const std::string& source,
                                               const std::string& target) {
  return nlohmann::json{
      {"kind", "relationship_create"},
      {"relationship_id", relationship_id},
      {"relationship", nlohmann::json{{"source_object_id", source}, {"target_object_id", target},
                                          {"relationship_type", "references"}, {"description", ""},
                                          {"author", "wp-srv-012"}}},
  };
}

nlohmann::json relationship_delete_mutation(const std::string& relationship_id, std::int64_t expected_revision) {
  return nlohmann::json{
      {"kind", "relationship_delete"},
      {"relationship_id", relationship_id},
      {"expected_revision", expected_revision},
  };
}

nlohmann::json commit_body(const std::string& operation_id, std::vector<nlohmann::json> mutations) {
  return nlohmann::json{{"operation_id", operation_id}, {"mutations", std::move(mutations)}};
}

int count_rows(pqxx::connection& connection, const std::string& sql) {
  pqxx::work txn(connection);
  const auto result = txn.exec(sql);
  txn.commit();
  return result[0][0].as<int>();
}

}  // namespace

TEST_CASE("WP-SRV-012: object/relationship tombstone (delete) semantics", "[api][tombstone][database]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  ServerRepositoryStore store(test_database_config());
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;
  ApiServer server(config, kTestApiToken, store);
  REQUIRE(server.start());
  httplib::Client client(config.host, server.bound_port());
  client.set_bearer_token_auth(kTestApiToken);

  pqxx::connection db_connection(
      oep::server_repository::common::Config{.database = test_database_config()}.database_connection_string());

  const std::string repository_id = [&] {
    const auto response = client.Post(
        "/api/v1/repositories", nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Tombstone Test Repo"}}.dump(),
        "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  }();

  // Requirement 1: delete a live object with no relationships -> success,
  // tombstone revision created.
  SECTION("delete a live object with no relationships succeeds and creates a tombstone revision") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doomed")}).dump(),
                 "application/json");

    const auto response = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                        commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(),
                                        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    const auto result = nlohmann::json::parse(response->body);
    CHECK(result.at("object_results")[0].at("object_id") == object_id);
    CHECK(result.at("object_results")[0].at("revision") == 2);
  }

  // Requirement 2: current GET of a tombstoned object -> deterministic
  // response. ADR-0006's error category list is closed (SS13) and has no
  // distinct "tombstoned" category -- NOT_FOUND already covers "no live
  // current state exists for that id" exactly, so this reuses it (with a
  // distinguishing message) rather than the API inventing a new category/
  // status code.
  SECTION("current GET of a tombstoned object returns a deterministic NOT_FOUND, not the stale content") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doomed")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 404);
    CHECK(nlohmann::json::parse(current->body).at("error") == "NOT_FOUND");
  }

  // Requirement 3: historical GET before deletion -> original revision
  // remains retrievable.
  SECTION("historical GET of the pre-delete revision remains retrievable, unaffected by the later delete") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const auto revision_1 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/1");
    REQUIRE(revision_1 != nullptr);
    CHECK(revision_1->status == 200);
    const auto body = nlohmann::json::parse(revision_1->body);
    CHECK(body.at("name") == "Original");
    CHECK(body.at("tombstoned") == false);
  }

  // Requirement 4: historical GET of the tombstone revision itself ->
  // tombstone remains retrievable.
  SECTION("historical GET of the tombstone revision itself is retrievable and marked tombstoned") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const auto revision_2 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/2");
    REQUIRE(revision_2 != nullptr);
    CHECK(revision_2->status == 200);
    const auto body = nlohmann::json::parse(revision_2->body);
    CHECK(body.at("tombstoned") == true);
    // Content copied forward from the pre-delete revision, per ADR-0006's
    // "a delete is a specific kind of mutation, not a different,
    // non-revisioned operation" -- the tombstone still carries meaningful
    // metadata, it isn't blanked.
    CHECK(body.at("name") == "Original");
  }

  // Requirement 5: delete a live relationship -> success, tombstone
  // revision created.
  SECTION("delete a live relationship succeeds and creates a tombstone revision") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");

    const auto response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {relationship_delete_mutation(relationship_id, 1)}).dump(),
                     "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    CHECK(nlohmann::json::parse(response->body).at("relationship_results")[0].at("revision") == 2);

    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 404);
  }

  // Requirement 6: delete object with a live relationship -> rejected,
  // no mutation persisted.
  SECTION("delete object with a live relationship is rejected, and nothing persists") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");

    const auto response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_delete_mutation(object_a, 1)}).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");

    const auto object_check = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_a);
    REQUIRE(object_check != nullptr);
    CHECK(object_check->status == 200);
    CHECK(nlohmann::json::parse(object_check->body).at("revision") == 1);

    const auto relationship_check = client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_id);
    REQUIRE(relationship_check != nullptr);
    CHECK(relationship_check->status == 200);
  }

  // Requirement 7 (and 18): delete object plus ALL its live relationships
  // in one commit -> success, all become tombstoned atomically.
  SECTION("delete object plus all its live relationships in one commit succeeds atomically") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string object_c = generate_uuid_v4();
    const std::string relationship_1 = generate_uuid_v4();
    const std::string relationship_2 = generate_uuid_v4();
    client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                            object_create_mutation(object_c, "C"),
                                            relationship_create_mutation(relationship_1, object_a, object_b),
                                            relationship_create_mutation(relationship_2, object_a, object_c)})
            .dump(),
        "application/json");

    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_delete_mutation(object_a, 1), relationship_delete_mutation(relationship_1, 1),
                                            relationship_delete_mutation(relationship_2, 1)})
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_a)->status == 404);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_1)->status == 404);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_2)->status == 404);
  }

  // Requirement 18, single-relationship variant of 7.
  SECTION("object with exactly one live relationship, deleted together in one commit, succeeds atomically") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");

    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_delete_mutation(object_a, 1), relationship_delete_mutation(relationship_id, 1)})
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_a)->status == 404);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_id)->status == 404);
  }

  // Requirement 8: delete object plus only SOME of its live relationships
  // -> rejected, NOTHING persists.
  SECTION("delete object plus only some of its live relationships is rejected, nothing persists") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string object_c = generate_uuid_v4();
    const std::string relationship_1 = generate_uuid_v4();
    const std::string relationship_2 = generate_uuid_v4();
    client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                            object_create_mutation(object_c, "C"),
                                            relationship_create_mutation(relationship_1, object_a, object_b),
                                            relationship_create_mutation(relationship_2, object_a, object_c)})
            .dump(),
        "application/json");

    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_delete_mutation(object_a, 1), relationship_delete_mutation(relationship_1, 1)})
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");

    // NOTHING persists -- not even relationship_1's own deletion, despite
    // being individually valid.
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_a)->status == 200);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_1)->status == 200);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_2)->status == 200);
  }

  // Requirement 9: mixed valid + invalid deletion commit -> complete
  // rollback.
  SECTION("a mixed valid-delete + invalid-mutation commit rolls back completely") {
    const std::string object_x = generate_uuid_v4();
    const std::string object_y = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_x, "X"), object_create_mutation(object_y, "Y")})
                     .dump(),
                 "application/json");

    // X's delete is individually valid (expected_revision=1, no
    // relationships); Y's delete uses a deliberately stale
    // expected_revision (99) -- the whole commit must be rejected, and X
    // must NOT be tombstoned even though its own mutation was valid.
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_delete_mutation(object_x, 1), object_delete_mutation(object_y, 99)}).dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "CONCURRENCY_CONFLICT");

    const auto x_check = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_x);
    REQUIRE(x_check != nullptr);
    CHECK(x_check->status == 200);
    CHECK(nlohmann::json::parse(x_check->body).at("revision") == 1);
  }

  // Requirement 10: stale object deletion -> existing concurrency
  // conflict behavior.
  SECTION("a stale object deletion is rejected via the existing concurrency-conflict mechanism") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "v1")}).dump(), "application/json");
    // Client B updates first: revision 1 -> 2.
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_update_mutation(object_id, 1, "v2")}).dump(), "application/json");

    // Client A still believes revision 1 is current and tries to delete it.
    const auto stale = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                     commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(),
                                     "application/json");
    REQUIRE(stale != nullptr);
    CHECK(stale->status == 409);
    CHECK(nlohmann::json::parse(stale->body).at("error") == "CONCURRENCY_CONFLICT");

    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(nlohmann::json::parse(current->body).at("name") == "v2");
    CHECK(nlohmann::json::parse(current->body).at("revision") == 2);
  }

  // Requirement 11: stale relationship deletion -> existing concurrency
  // conflict behavior.
  SECTION("a stale relationship deletion is rejected via the existing concurrency-conflict mechanism") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");

    nlohmann::json update = nlohmann::json{
        {"kind", "relationship_update"},
        {"relationship_id", relationship_id},
        {"expected_revision", 1},
        {"relationship", nlohmann::json{{"source_object_id", object_a}, {"target_object_id", object_b},
                                            {"relationship_type", "documents"}, {"description", "updated"},
                                            {"author", "wp-srv-012"}}},
    };
    client.Post("/api/v1/repositories/" + repository_id + "/commits", commit_body(generate_uuid_v4(), {update}).dump(),
                 "application/json");

    const auto stale =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {relationship_delete_mutation(relationship_id, 1)}).dump(),
                     "application/json");
    REQUIRE(stale != nullptr);
    CHECK(stale->status == 409);
    CHECK(nlohmann::json::parse(stale->body).at("error") == "CONCURRENCY_CONFLICT");
  }

  // Requirement 12: exact idempotent retry of a deletion commit -> the
  // original result, not reapplied.
  SECTION("an exact idempotent retry of a deletion commit returns the original result, is not reapplied") {
    const std::string object_id = generate_uuid_v4();
    const std::string operation_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doomed")}).dump(),
                 "application/json");

    const auto body = commit_body(operation_id, {object_delete_mutation(object_id, 1)});
    const auto first = client.Post("/api/v1/repositories/" + repository_id + "/commits", body.dump(), "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);
    const std::string commit_id = nlohmann::json::parse(first->body).at("commit_id").get<std::string>();

    const auto second = client.Post("/api/v1/repositories/" + repository_id + "/commits", body.dump(), "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 201);
    CHECK(nlohmann::json::parse(second->body).at("commit_id") == commit_id);

    // The revision only advanced once (1 -> 2), not twice (would be 3 if
    // the delete were mistakenly reapplied).
    const auto revision_check =
        client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/3");
    REQUIRE(revision_check != nullptr);
    CHECK(revision_check->status == 404);
  }

  // Requirement 13: same operation_id, changed deletion content ->
  // IDEMPOTENCY_CONFLICT.
  SECTION("reusing a deletion commit's operation_id with different content is an idempotency conflict") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B")})
                     .dump(),
                 "application/json");

    const std::string operation_id = generate_uuid_v4();
    const auto first = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                     commit_body(operation_id, {object_delete_mutation(object_a, 1)}).dump(),
                                     "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);

    const auto second = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                      commit_body(operation_id, {object_delete_mutation(object_b, 1)}).dump(),
                                      "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 409);
    CHECK(nlohmann::json::parse(second->body).at("error") == "IDEMPOTENCY_CONFLICT");
  }

  // Requirement 15: deletion has correct commit/revision/audit linkage.
  SECTION("a deletion's audit association carries the correct commit/revision linkage") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doomed")}).dump(),
                 "application/json");
    const auto response = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                        commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(),
                                        "application/json");
    const std::string commit_id = nlohmann::json::parse(response->body).at("commit_id").get<std::string>();

    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM audit_events WHERE commit_id = '" + commit_id +
                                          "' AND event_type = 'commit_applied'") == 1);
    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM commit_mutations WHERE commit_id = '" + commit_id +
                                          "' AND entity_id = '" + object_id + "' AND resulting_revision = 2 AND "
                                          "is_delete = true") == 1);
  }

  // Requirement 16: UUIDv4 negative validation for deletion identities.
  SECTION("a non-UUIDv4 identity in a deletion mutation is rejected before any database mutation") {
    // A real, well-known UUIDv1 example (RFC 4122), not a hand-edited
    // string -- same convention as WP-SRV-011C's own UUID tests.
    constexpr auto kUuidV1 = "550e8400-e29b-11d4-a716-446655440000";
    const auto response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_delete_mutation(kUuidV1, 1)}).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  // Requirement 17: no physical deletion -- historical database state
  // remains present after tombstoning.
  SECTION("tombstoning never physically deletes a row -- both revisions remain in the database") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doomed")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM objects WHERE object_id = '" + object_id + "'") == 2);
    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM objects WHERE object_id = '" + object_id +
                                          "' AND revision = 1 AND NOT is_tombstoned") == 1);
    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM objects WHERE object_id = '" + object_id +
                                          "' AND revision = 2 AND is_tombstoned") == 1);
  }

  // Restoration: an ordinary update mutation against a tombstoned
  // identity restores it to a LIVE state -- expressed entirely through
  // the existing commit contract, no new API surface (ADR-0006 SS10).
  SECTION("restoration: a normal update mutation against a tombstoned object creates a new live revision") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const auto restore =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_update_mutation(object_id, 2, "Restored")}).dump(),
                     "application/json");
    REQUIRE(restore != nullptr);
    CHECK(restore->status == 201);

    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 200);
    const auto body = nlohmann::json::parse(current->body);
    CHECK(body.at("tombstoned") == false);
    CHECK(body.at("name") == "Restored");
    CHECK(body.at("revision") == 3);
  }

  // A relationship create/update must not be permitted against a
  // tombstoned endpoint object -- deletion must not weaken the existing
  // "relationship endpoints must exist" invariant.
  SECTION("creating a relationship against a tombstoned endpoint object is rejected") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B")})
                     .dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_a, 1)}).dump(), "application/json");

    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {relationship_create_mutation(generate_uuid_v4(), object_a, object_b)}).dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  server.stop();
}

// Requirement 14: tombstones survive server restart.
TEST_CASE("WP-SRV-012: tombstones survive a server restart", "[api][tombstone][database]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string object_id = generate_uuid_v4();
  std::string repository_id;

  {
    ServerRepositoryStore store(test_database_config());
    ServerConfig config;
    config.host = "127.0.0.1";
    config.port = 0;
    ApiServer server(config, kTestApiToken, store);
    REQUIRE(server.start());
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);

    const auto repo_response = client.Post(
        "/api/v1/repositories", nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Restart Tombstone Repo"}}.dump(),
        "application/json");
    repository_id = nlohmann::json::parse(repo_response->body).at("id").get<std::string>();

    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doomed")}).dump(),
                 "application/json");
    const auto delete_response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");
    REQUIRE(delete_response != nullptr);
    REQUIRE(delete_response->status == 201);
    server.stop();
  }

  {
    // A fresh store/server instance -- same durability argument as
    // WP-SRV-011's own restart tests.
    ServerRepositoryStore store(test_database_config());
    ServerConfig config;
    config.host = "127.0.0.1";
    config.port = 0;
    ApiServer server(config, kTestApiToken, store);
    REQUIRE(server.start());
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);

    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 404);

    const auto revision_2 =
        client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/2");
    REQUIRE(revision_2 != nullptr);
    CHECK(revision_2->status == 200);
    CHECK(nlohmann::json::parse(revision_2->body).at("tombstoned") == true);

    server.stop();
  }
}

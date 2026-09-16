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

// WP-SRV-012A: a create-shaped mutation. `expected_revision` is omitted
// for a plain first-time create, and supplied for a create-shaped
// restoration against a tombstoned identity (ADR-0006 SS10).
nlohmann::json object_create_mutation(const std::string& object_id, const std::string& name,
                                        std::optional<std::int64_t> expected_revision = std::nullopt) {
  nlohmann::json mutation = nlohmann::json{
      {"kind", "object_create"},
      {"object_id", object_id},
      {"object", nlohmann::json{{"object_type", "document"}, {"name", name}, {"description", "test object"},
                                   {"author", "wp-srv-012a"}, {"tags", nlohmann::json::array()},
                                   {"content", "hello"}, {"version", "1.0.0"}}},
  };
  if (expected_revision.has_value()) {
    mutation["expected_revision"] = *expected_revision;
  }
  return mutation;
}

nlohmann::json object_delete_mutation(const std::string& object_id, std::int64_t expected_revision) {
  return nlohmann::json{
      {"kind", "object_delete"},
      {"object_id", object_id},
      {"expected_revision", expected_revision},
  };
}

nlohmann::json relationship_create_mutation(const std::string& relationship_id, const std::string& source,
                                               const std::string& target,
                                               std::optional<std::int64_t> expected_revision = std::nullopt) {
  nlohmann::json mutation = nlohmann::json{
      {"kind", "relationship_create"},
      {"relationship_id", relationship_id},
      {"relationship", nlohmann::json{{"source_object_id", source}, {"target_object_id", target},
                                          {"relationship_type", "references"}, {"description", ""},
                                          {"author", "wp-srv-012a"}}},
  };
  if (expected_revision.has_value()) {
    mutation["expected_revision"] = *expected_revision;
  }
  return mutation;
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

}  // namespace

TEST_CASE("WP-SRV-012A: create-shaped tombstone restoration", "[api][tombstone][restoration][database]") {
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

  const std::string repository_id = [&] {
    const auto response = client.Post(
        "/api/v1/repositories",
        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Restoration Test Repo"}}.dump(),
        "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  }();

  // Requirements 1-7: the full create -> delete -> create(restore)
  // sequence, with historical retrieval and current GET checked at every
  // stage.
  SECTION("create -> delete -> create-shaped restore: full revision history and current-state sequence") {
    const std::string object_id = generate_uuid_v4();

    // 1. Object create against a nonexistent identity -> revision 1 LIVE.
    const auto create_response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                     "application/json");
    REQUIRE(create_response != nullptr);
    CHECK(create_response->status == 201);
    CHECK(nlohmann::json::parse(create_response->body).at("object_results")[0].at("revision") == 1);

    // 2. Object delete -> revision 2 TOMBSTONED.
    const auto delete_response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");
    REQUIRE(delete_response != nullptr);
    CHECK(delete_response->status == 201);
    CHECK(nlohmann::json::parse(delete_response->body).at("object_results")[0].at("revision") == 2);

    // 3. Object create against the same tombstoned identity -> success,
    // revision 3 LIVE. Wire mutation kind remains "object_create".
    const auto restore_response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Restored", 2)}).dump(), "application/json");
    REQUIRE(restore_response != nullptr);
    CHECK(restore_response->status == 201);
    const auto restore_result = nlohmann::json::parse(restore_response->body);
    CHECK(restore_result.at("object_results")[0].at("object_id") == object_id);
    CHECK(restore_result.at("object_results")[0].at("revision") == 3);

    // 4. Historical revision 1 remains LIVE.
    const auto rev1 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/1");
    REQUIRE(rev1 != nullptr);
    CHECK(rev1->status == 200);
    const auto rev1_body = nlohmann::json::parse(rev1->body);
    CHECK(rev1_body.at("tombstoned") == false);
    CHECK(rev1_body.at("name") == "Original");

    // 5. Historical revision 2 remains TOMBSTONED, unchanged by the
    // later restoration.
    const auto rev2 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/2");
    REQUIRE(rev2 != nullptr);
    CHECK(rev2->status == 200);
    const auto rev2_body = nlohmann::json::parse(rev2->body);
    CHECK(rev2_body.at("tombstoned") == true);
    CHECK(rev2_body.at("name") == "Original");

    // 6. Historical revision 3 is LIVE.
    const auto rev3 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/3");
    REQUIRE(rev3 != nullptr);
    CHECK(rev3->status == 200);
    const auto rev3_body = nlohmann::json::parse(rev3->body);
    CHECK(rev3_body.at("tombstoned") == false);
    CHECK(rev3_body.at("name") == "Restored");

    // 7. Current GET after restoration -> 200, revision 3, tombstoned=false.
    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 200);
    const auto current_body = nlohmann::json::parse(current->body);
    CHECK(current_body.at("revision") == 3);
    CHECK(current_body.at("tombstoned") == false);
    CHECK(current_body.at("name") == "Restored");
  }

  // Requirement 8: create against an ALREADY LIVE identity -> existing
  // duplicate-identity validation behavior, unaffected by restoration.
  SECTION("object create against an already-live identity is still rejected as a duplicate") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");

    const auto response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Duplicate")}).dump(),
                     "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");

    // Untouched -- still revision 1, original content.
    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(nlohmann::json::parse(current->body).at("revision") == 1);
    CHECK(nlohmann::json::parse(current->body).at("name") == "Original");
  }

  // Requirement 9: a stale create-shaped restoration -> CONCURRENCY_CONFLICT.
  SECTION("a stale create-shaped restoration attempt is rejected as a concurrency conflict") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    // The tombstone is at revision 2; a restoration attempt claiming
    // expected_revision=1 is stale.
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Restored", 1)}).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "CONCURRENCY_CONFLICT");

    // Still tombstoned -- the stale attempt did not restore it.
    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(current->status == 404);
  }

  // Missing expected_revision entirely against a tombstoned identity must
  // also be rejected as a concurrency conflict, not silently treated as
  // "any revision is fine" (no last-write-wins).
  SECTION("a create-shaped restoration with no expected_revision at all is rejected") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const auto response =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Restored")}).dump(),
                     "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "CONCURRENCY_CONFLICT");
  }

  // Requirement 10: exact idempotent restoration retry -> original
  // commit/result.
  SECTION("an exact idempotent retry of a create-shaped restoration returns the original result") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const auto body = commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Restored", 2)});
    const auto first = client.Post("/api/v1/repositories/" + repository_id + "/commits", body.dump(), "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);
    const std::string commit_id = nlohmann::json::parse(first->body).at("commit_id").get<std::string>();

    const auto second = client.Post("/api/v1/repositories/" + repository_id + "/commits", body.dump(), "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 201);
    CHECK(nlohmann::json::parse(second->body).at("commit_id") == commit_id);

    // Not reapplied -- still revision 3, not 4.
    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(nlohmann::json::parse(current->body).at("revision") == 3);
  }

  // Requirement 11: reused operation_id with different restoration
  // content -> IDEMPOTENCY_CONFLICT.
  SECTION("reusing a restoration commit's operation_id with different content is an idempotency conflict") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");

    const std::string operation_id = generate_uuid_v4();
    const auto first =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(operation_id, {object_create_mutation(object_id, "Restored As Alpha", 2)}).dump(),
                     "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);

    const auto second =
        client.Post("/api/v1/repositories/" + repository_id + "/commits",
                     commit_body(operation_id, {object_create_mutation(object_id, "Restored As Beta", 2)}).dump(),
                     "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 409);
    CHECK(nlohmann::json::parse(second->body).at("error") == "IDEMPOTENCY_CONFLICT");
  }

  // Requirement 12: relationship delete followed by relationship_create
  // restoration -> new live revision.
  SECTION("relationship delete followed by a create-shaped relationship restoration succeeds") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {relationship_delete_mutation(relationship_id, 1)}).dump(),
                 "application/json");

    const auto restore = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {relationship_create_mutation(relationship_id, object_a, object_b, 2)}).dump(),
        "application/json");
    REQUIRE(restore != nullptr);
    CHECK(restore->status == 201);
    CHECK(nlohmann::json::parse(restore->body).at("relationship_results")[0].at("revision") == 3);

    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 200);
    CHECK(nlohmann::json::parse(current->body).at("tombstoned") == false);
  }

  // Requirement 13: relationship restoration against a tombstoned
  // endpoint object -> VALIDATION_FAILED.
  SECTION("relationship restoration against a currently-tombstoned endpoint object is rejected") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");
    // Delete both the relationship and one of its endpoint objects (the
    // object delete is valid here because the relationship is deleted
    // in the same commit, per WP-SRV-012).
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {relationship_delete_mutation(relationship_id, 1), object_delete_mutation(object_a, 1)})
                     .dump(),
                 "application/json");

    // object_a is now tombstoned; attempting to restore the relationship
    // (without first restoring object_a) must fail.
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {relationship_create_mutation(relationship_id, object_a, object_b, 2)}).dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");

    // The relationship remains tombstoned.
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_id)->status == 404);
  }

  // Requirement 14: object restoration does NOT automatically restore
  // its relationships.
  SECTION("restoring an object does not automatically restore its previously-tombstoned relationships") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                                     relationship_create_mutation(relationship_id, object_a, object_b)})
                     .dump(),
                 "application/json");
    // Object A revision 2 = TOMBSTONED, Relationship R revision 2 = TOMBSTONED.
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {relationship_delete_mutation(relationship_id, 1), object_delete_mutation(object_a, 1)})
                     .dump(),
                 "application/json");

    // Restoring A alone: Object A revision 3 = LIVE.
    const auto restore_a = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                         commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A Restored", 2)}).dump(),
                                         "application/json");
    REQUIRE(restore_a != nullptr);
    CHECK(restore_a->status == 201);
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_a)->status == 200);

    // R remains tombstoned -- restoring A did not touch it.
    const auto relationship_check = client.Get("/api/v1/repositories/" + repository_id + "/relationships/" + relationship_id);
    REQUIRE(relationship_check != nullptr);
    CHECK(relationship_check->status == 404);
  }

  // Requirement 15: mixed restoration + invalid mutation -> entire
  // commit rolls back.
  SECTION("a mixed valid-restoration + invalid-mutation commit rolls back completely") {
    const std::string object_x = generate_uuid_v4();
    const std::string object_y = generate_uuid_v4();
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_x, "X"), object_create_mutation(object_y, "Y")})
                     .dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_x, 1)}).dump(), "application/json");

    // X's restoration is individually valid (expected_revision=2, its
    // tombstone). Y's mutation is a deliberately invalid duplicate-create
    // (Y is still live) -- the whole commit must reject, and X must NOT
    // be restored even though its own mutation was valid.
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_x, "X Restored", 2), object_create_mutation(object_y, "Y Duplicate")})
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");

    // X is still tombstoned -- nothing persisted from this commit.
    CHECK(client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_x)->status == 404);
  }

  server.stop();
}

// Requirement 16: restart persistence after restoration.
TEST_CASE("WP-SRV-012A: create-shaped restoration survives a server restart", "[api][tombstone][restoration][database]") {
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
        "/api/v1/repositories",
        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Restart Restoration Repo"}}.dump(),
        "application/json");
    repository_id = nlohmann::json::parse(repo_response->body).at("id").get<std::string>();

    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Original")}).dump(),
                 "application/json");
    client.Post("/api/v1/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_delete_mutation(object_id, 1)}).dump(), "application/json");
    const auto restore_response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Restored", 2)}).dump(), "application/json");
    REQUIRE(restore_response != nullptr);
    REQUIRE(restore_response->status == 201);
    server.stop();
  }

  {
    // A fresh store/server instance -- same durability argument as
    // WP-SRV-011/WP-SRV-012's own restart tests.
    ServerRepositoryStore store(test_database_config());
    ServerConfig config;
    config.host = "127.0.0.1";
    config.port = 0;
    ApiServer server(config, kTestApiToken, store);
    REQUIRE(server.start());
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);

    // Live revision survives restart.
    const auto current = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 200);
    const auto current_body = nlohmann::json::parse(current->body);
    CHECK(current_body.at("revision") == 3);
    CHECK(current_body.at("tombstoned") == false);
    CHECK(current_body.at("name") == "Restored");

    // Tombstone history remains retrievable.
    const auto rev2 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/2");
    REQUIRE(rev2 != nullptr);
    CHECK(rev2->status == 200);
    CHECK(nlohmann::json::parse(rev2->body).at("tombstoned") == true);

    const auto rev1 = client.Get("/api/v1/repositories/" + repository_id + "/objects/" + object_id + "/revisions/1");
    REQUIRE(rev1 != nullptr);
    CHECK(rev1->status == 200);
    CHECK(nlohmann::json::parse(rev1->body).at("tombstoned") == false);

    server.stop();
  }
}

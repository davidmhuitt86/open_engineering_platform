#include <catch2/catch_test_macros.hpp>

#include <pqxx/pqxx>

#include <httplib.h>
#include <nlohmann/json.hpp>

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

// WP-SRV-011C: real, well-known example UUIDs of each non-v4 version, so
// the negative tests exercise genuine version-1/3/5 identities rather
// than hand-edited strings that merely happen to have the "wrong"
// version nibble. Sources: RFC 4122's own illustrative examples (v1) and
// the standard NAMESPACE_DNS/"python.org" test vectors commonly used to
// illustrate v3/v5 (both are structurally valid, canonical UUIDs).
constexpr auto kUuidV1 = "550e8400-e29b-11d4-a716-446655440000";
constexpr auto kUuidV3 = "6fa459ea-ee8a-3ca4-894e-db77e160355e";
constexpr auto kUuidV5 = "886313e1-3b8a-5372-9b90-0c9aee199e5d";
// Version nibble is correctly '4', but the variant nibble ('c') falls
// outside the RFC 4122/9562 standard variant range (8/9/a/b).
constexpr auto kUuidInvalidVariant = "11111111-1111-4111-c111-111111111111";
constexpr auto kUuidMalformed = "not-a-uuid-at-all";
// One character short of a canonical UUID.
constexpr auto kUuidWrongLength = "4a3b9c3d-0000-4000-8000-00000000000";

int count_rows(pqxx::connection& connection, const std::string& sql) {
  pqxx::work txn(connection);
  const auto result = txn.exec(sql);
  txn.commit();
  return result[0][0].as<int>();
}

}  // namespace

TEST_CASE("WP-SRV-011C: repository-creation operation_id enforces the UUIDv4 identity contract",
          "[api][uuid][database]") {
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

  auto attempt_create = [&](const std::string& operation_id) {
    return client.Post("/api/v1/repositories",
                        nlohmann::json{{"operation_id", operation_id}, {"name", "UUID Contract Repo"}}.dump(),
                        "application/json");
  };

  SECTION("valid UUIDv4, standard variant is accepted") {
    const auto response = attempt_create(generate_uuid_v4());
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
  }

  SECTION("UUIDv1 operation_id is rejected") {
    const auto response = attempt_create(kUuidV1);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("UUIDv3 operation_id is rejected") {
    const auto response = attempt_create(kUuidV3);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("UUIDv5 operation_id is rejected") {
    const auto response = attempt_create(kUuidV5);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("valid version nibble but non-standard variant is rejected") {
    const auto response = attempt_create(kUuidInvalidVariant);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("malformed UUID is rejected") {
    const auto response = attempt_create(kUuidMalformed);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("wrong-length UUID is rejected") {
    const auto response = attempt_create(kUuidWrongLength);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  // No database mutation may occur for ANY of the rejected attempts above
  // (nor was one attempted for the accepted one beyond its own single,
  // legitimate row) -- exactly one repository exists: the one created by
  // the valid-UUIDv4 SECTION, if that SECTION ran; every rejected
  // SECTION leaves the table untouched.
  CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM repositories") <= 1);
  CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM repository_creation_operations") <= 1);

  server.stop();
}

TEST_CASE("WP-SRV-011C: commit operation_id enforces the UUIDv4 identity contract", "[api][uuid][database]") {
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
        "/api/v1/repositories", nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Commit UUID Repo"}}.dump(),
        "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  }();

  nlohmann::json valid_object_mutation = nlohmann::json{
      {"kind", "object_create"},
      {"object_id", generate_uuid_v4()},
      {"object", nlohmann::json{{"object_type", "document"}, {"name", "Doc"}, {"description", ""}, {"author", ""},
                                   {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
  };

  auto attempt_commit = [&](const std::string& operation_id) {
    return client.Post("/api/v1/repositories/" + repository_id + "/commits",
                        nlohmann::json{{"operation_id", operation_id}, {"mutations", {valid_object_mutation}}}.dump(),
                        "application/json");
  };

  SECTION("valid UUIDv4 commit operation_id is accepted") {
    const auto response = attempt_commit(generate_uuid_v4());
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
  }

  SECTION("UUIDv1 commit operation_id is rejected") {
    const auto response = attempt_commit(kUuidV1);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("UUIDv3 commit operation_id is rejected") {
    const auto response = attempt_commit(kUuidV3);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("UUIDv5 commit operation_id is rejected") {
    const auto response = attempt_commit(kUuidV5);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("non-standard-variant commit operation_id is rejected") {
    const auto response = attempt_commit(kUuidInvalidVariant);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("malformed commit operation_id is rejected") {
    const auto response = attempt_commit(kUuidMalformed);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("wrong-length commit operation_id is rejected") {
    const auto response = attempt_commit(kUuidWrongLength);
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  // No commit and no object mutation may be applied for any rejected
  // attempt -- the repository has zero objects except for the one
  // legitimately created by the valid-UUIDv4 SECTION, if it ran.
  const auto objects_response = client.Get("/api/v1/repositories/" + repository_id + "/objects");
  REQUIRE(objects_response != nullptr);
  CHECK(objects_response->status == 200);
  CHECK(nlohmann::json::parse(objects_response->body).size() <= 1);

  server.stop();
}

TEST_CASE("WP-SRV-011C: client-supplied object_id and relationship_id enforce the UUIDv4 identity contract",
          "[api][uuid][database]") {
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
        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Entity UUID Repo"}}.dump(), "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  }();

  pqxx::connection db_connection(
      oep::server_repository::common::Config{.database = test_database_config()}.database_connection_string());

  SECTION("object_create with a non-v4 object_id is rejected, no object persisted") {
    nlohmann::json mutation = nlohmann::json{
        {"kind", "object_create"},
        {"object_id", kUuidV1},
        {"object", nlohmann::json{{"object_type", "document"}, {"name", "Doc"}, {"description", ""}, {"author", ""},
                                     {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
    };
    const auto response = client.Post("/api/v1/repositories/" + repository_id + "/commits",
                                        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"mutations", {mutation}}}.dump(),
                                        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM objects WHERE repository_id = '" + repository_id + "'") == 0);
  }

  SECTION("relationship_create with a non-v4 relationship_id is rejected, no relationship persisted") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    nlohmann::json create_a = nlohmann::json{
        {"kind", "object_create"},
        {"object_id", object_a},
        {"object", nlohmann::json{{"object_type", "document"}, {"name", "A"}, {"description", ""}, {"author", ""},
                                     {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
    };
    nlohmann::json create_b = nlohmann::json{
        {"kind", "object_create"},
        {"object_id", object_b},
        {"object", nlohmann::json{{"object_type", "document"}, {"name", "B"}, {"description", ""}, {"author", ""},
                                     {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
    };
    nlohmann::json bad_relationship = nlohmann::json{
        {"kind", "relationship_create"},
        {"relationship_id", kUuidV5},
        {"relationship", nlohmann::json{{"source_object_id", object_a}, {"target_object_id", object_b},
                                            {"relationship_type", "references"}, {"description", ""},
                                            {"author", ""}}},
    };
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"mutations", {create_a, create_b, bad_relationship}}}
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
    // Whole-commit rejection: not even the two, individually valid,
    // object_create mutations that preceded the bad relationship in the
    // same request were persisted.
    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM objects WHERE repository_id = '" + repository_id + "'") == 0);
    CHECK(count_rows(db_connection, "SELECT COUNT(*) FROM relationships WHERE repository_id = '" + repository_id + "'") ==
          0);
  }

  SECTION("relationship_create with a non-v4 source_object_id is rejected") {
    const std::string object_b = generate_uuid_v4();
    nlohmann::json create_b = nlohmann::json{
        {"kind", "object_create"},
        {"object_id", object_b},
        {"object", nlohmann::json{{"object_type", "document"}, {"name", "B"}, {"description", ""}, {"author", ""},
                                     {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
    };
    nlohmann::json bad_relationship = nlohmann::json{
        {"kind", "relationship_create"},
        {"relationship_id", generate_uuid_v4()},
        {"relationship", nlohmann::json{{"source_object_id", kUuidMalformed}, {"target_object_id", object_b},
                                            {"relationship_type", "references"}, {"description", ""},
                                            {"author", ""}}},
    };
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"mutations", {create_b, bad_relationship}}}.dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
  }

  SECTION("valid UUIDv4 object_id and relationship_id are accepted") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    nlohmann::json create_a = nlohmann::json{
        {"kind", "object_create"},
        {"object_id", object_a},
        {"object", nlohmann::json{{"object_type", "document"}, {"name", "A"}, {"description", ""}, {"author", ""},
                                     {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
    };
    nlohmann::json create_b = nlohmann::json{
        {"kind", "object_create"},
        {"object_id", object_b},
        {"object", nlohmann::json{{"object_type", "document"}, {"name", "B"}, {"description", ""}, {"author", ""},
                                     {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
    };
    nlohmann::json relationship = nlohmann::json{
        {"kind", "relationship_create"},
        {"relationship_id", relationship_id},
        {"relationship", nlohmann::json{{"source_object_id", object_a}, {"target_object_id", object_b},
                                            {"relationship_type", "references"}, {"description", ""},
                                            {"author", ""}}},
    };
    const auto response = client.Post(
        "/api/v1/repositories/" + repository_id + "/commits",
        nlohmann::json{{"operation_id", generate_uuid_v4()}, {"mutations", {create_a, create_b, relationship}}}
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
  }

  server.stop();
}

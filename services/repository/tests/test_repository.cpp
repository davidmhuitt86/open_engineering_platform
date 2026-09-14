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

nlohmann::json create_body(const std::string& operation_id, const std::string& name) {
  return nlohmann::json{{"operation_id", operation_id}, {"name", name}, {"description", "a test repository"}};
}

// Direct DB query -- there is no administrative audit-retrieval API
// (WP-SRV-011 Scope Exclusions: "administrative APIs" are out of scope),
// so tests confirm audit association the same way EAM's own test suite
// confirms things the API deliberately doesn't expose: querying the
// database directly.
int count_audit_events(const std::string& repository_id, const std::string& event_type) {
  pqxx::connection connection(
      oep::server_repository::common::Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);
  const auto result = txn.exec_params(
      "SELECT COUNT(*) FROM audit_events WHERE repository_id = $1::uuid AND event_type = $2",
      pqxx::params{repository_id, event_type});
  txn.commit();
  return result[0][0].as<int>();
}

}  // namespace

TEST_CASE("Repository creation, retrieval, idempotency, and audit association", "[api][repository][database]") {
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

  SECTION("create and retrieve a repository") {
    const std::string operation_id = generate_uuid_v4();
    const auto response = client.Post("/api/v1/repositories", create_body(operation_id, "Repo A").dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    const auto body = nlohmann::json::parse(response->body);
    const std::string repository_id = body.at("id").get<std::string>();
    CHECK_FALSE(repository_id.empty());
    CHECK(body.at("name") == "Repo A");

    const auto get_response = client.Get("/api/v1/repositories/" + repository_id);
    REQUIRE(get_response != nullptr);
    CHECK(get_response->status == 200);
    CHECK(nlohmann::json::parse(get_response->body).at("id") == repository_id);
  }

  SECTION("repository-creation audit association") {
    const std::string operation_id = generate_uuid_v4();
    const auto response = client.Post("/api/v1/repositories", create_body(operation_id, "Audited Repo").dump(),
                                        "application/json");
    REQUIRE(response != nullptr);
    const std::string repository_id = nlohmann::json::parse(response->body).at("id").get<std::string>();
    CHECK(count_audit_events(repository_id, "repository_created") == 1);
  }

  SECTION("idempotent retry with identical content returns the original repository, does not create a second one") {
    const std::string operation_id = generate_uuid_v4();
    const auto body = create_body(operation_id, "Idempotent Repo");

    const auto first = client.Post("/api/v1/repositories", body.dump(), "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);
    const std::string first_id = nlohmann::json::parse(first->body).at("id").get<std::string>();

    const auto second = client.Post("/api/v1/repositories", body.dump(), "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 201);
    const std::string second_id = nlohmann::json::parse(second->body).at("id").get<std::string>();

    CHECK(first_id == second_id);

    // No second repository was created -- exactly one row exists.
    pqxx::connection connection(
        oep::server_repository::common::Config{.database = test_database_config()}.database_connection_string());
    pqxx::work txn(connection);
    const auto count = txn.exec("SELECT COUNT(*) FROM repositories");
    txn.commit();
    CHECK(count[0][0].as<int>() == 1);
  }

  SECTION("reusing an operation_id with materially different content is an idempotency conflict") {
    const std::string operation_id = generate_uuid_v4();
    const auto first = client.Post("/api/v1/repositories", create_body(operation_id, "Original Name").dump(),
                                     "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);

    const auto second = client.Post("/api/v1/repositories", create_body(operation_id, "Different Name").dump(),
                                      "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 409);
    CHECK(nlohmann::json::parse(second->body).at("error") == "IDEMPOTENCY_CONFLICT");
  }

  server.stop();
}

TEST_CASE("Repository-creation idempotency survives a restart", "[api][repository][database]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string operation_id = generate_uuid_v4();
  std::string original_repository_id;

  // "Restart" here means: a completely fresh ServerRepositoryStore (its
  // own new pqxx::connection, no shared state, no in-memory carryover
  // whatsoever with the instance above) is constructed against the same
  // durable database -- exactly the guarantee ADR-0006's correction
  // requires (the server-scoped idempotency namespace "MUST belong to
  // the Server Repository service's own persistence boundary -- not to
  // the memory of an individual running server process"). A real process
  // restart would exercise the identical code path (a fresh connection,
  // a fresh in-memory state, the same PostgreSQL rows) with no additional
  // architectural guarantee beyond what this proves.
  {
    ServerRepositoryStore store(test_database_config());
    ServerConfig config;
    config.host = "127.0.0.1";
    config.port = 0;
    ApiServer server(config, kTestApiToken, store);
    REQUIRE(server.start());
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);

    const auto response =
        client.Post("/api/v1/repositories", create_body(operation_id, "Restart Repo").dump(), "application/json");
    REQUIRE(response != nullptr);
    REQUIRE(response->status == 201);
    original_repository_id = nlohmann::json::parse(response->body).at("id").get<std::string>();
    server.stop();
  }

  {
    ServerRepositoryStore store(test_database_config());
    ServerConfig config;
    config.host = "127.0.0.1";
    config.port = 0;
    ApiServer server(config, kTestApiToken, store);
    REQUIRE(server.start());
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);

    const auto retry =
        client.Post("/api/v1/repositories", create_body(operation_id, "Restart Repo").dump(), "application/json");
    REQUIRE(retry != nullptr);
    CHECK(retry->status == 201);
    CHECK(nlohmann::json::parse(retry->body).at("id") == original_repository_id);

    // The previously-created repository itself is also still there.
    const auto get_response = client.Get("/api/v1/repositories/" + original_repository_id);
    REQUIRE(get_response != nullptr);
    CHECK(get_response->status == 200);

    server.stop();
  }
}

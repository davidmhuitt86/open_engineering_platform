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
                                   {"author", "wp-srv-011"}, {"tags", nlohmann::json::array({"a", "b"})},
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
                                   {"author", "wp-srv-011"}, {"tags", nlohmann::json::array()},
                                   {"content", "updated"}, {"version", "1.0.1"}}},
  };
}

nlohmann::json relationship_create_mutation(const std::string& relationship_id, const std::string& source,
                                               const std::string& target) {
  return nlohmann::json{
      {"kind", "relationship_create"},
      {"relationship_id", relationship_id},
      {"relationship", nlohmann::json{{"source_object_id", source}, {"target_object_id", target},
                                          {"relationship_type", "references"}, {"description", ""},
                                          {"author", "wp-srv-011"}}},
  };
}

nlohmann::json commit_body(const std::string& operation_id, std::vector<nlohmann::json> mutations) {
  return nlohmann::json{{"operation_id", operation_id}, {"mutations", std::move(mutations)}};
}

}  // namespace

TEST_CASE("Atomic commits: object/relationship creation, revisions, updates, concurrency, idempotency, audit",
          "[api][commit][database]") {
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
        "/repositories", nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Commit Test Repo"}}.dump(),
        "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  }();

  SECTION("object creation through commit, revision 1, retrievable current and historical") {
    const std::string object_id = generate_uuid_v4();
    const auto response = client.Post("/repositories/" + repository_id + "/commits",
                                        commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Doc A")}).dump(),
                                        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    const auto result = nlohmann::json::parse(response->body);
    CHECK(result.at("object_results")[0].at("object_id") == object_id);
    CHECK(result.at("object_results")[0].at("revision") == 1);

    const auto current = client.Get("/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 200);
    CHECK(nlohmann::json::parse(current->body).at("revision") == 1);
    CHECK(nlohmann::json::parse(current->body).at("name") == "Doc A");

    const auto historical = client.Get("/repositories/" + repository_id + "/objects/" + object_id + "/revisions/1");
    REQUIRE(historical != nullptr);
    CHECK(historical->status == 200);
    CHECK(nlohmann::json::parse(historical->body).at("name") == "Doc A");
  }

  SECTION("object and relationship created together in one commit") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    const auto response = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"), object_create_mutation(object_b, "B"),
                                            relationship_create_mutation(relationship_id, object_a, object_b)})
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    const auto result = nlohmann::json::parse(response->body);
    CHECK(result.at("object_results").size() == 2);
    CHECK(result.at("relationship_results").size() == 1);
    CHECK(result.at("relationship_results")[0].at("relationship_id") == relationship_id);

    const auto relationship = client.Get("/repositories/" + repository_id + "/relationships/" + relationship_id);
    REQUIRE(relationship != nullptr);
    CHECK(relationship->status == 200);
    CHECK(nlohmann::json::parse(relationship->body).at("source_object_id") == object_a);
    CHECK(nlohmann::json::parse(relationship->body).at("target_object_id") == object_b);
  }

  SECTION("relationship creation fails when an endpoint object does not exist") {
    const std::string object_a = generate_uuid_v4();
    const std::string nonexistent = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    const auto response = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_create_mutation(object_a, "A"),
                                            relationship_create_mutation(relationship_id, object_a, nonexistent)})
            .dump(),
        "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");

    // Failed transaction leaves no partial mutation: object_a must NOT
    // exist either, even though it appeared earlier in the same commit
    // and would, on its own, have been perfectly valid.
    const auto object_check = client.Get("/repositories/" + repository_id + "/objects/" + object_a);
    REQUIRE(object_check != nullptr);
    CHECK(object_check->status == 404);
  }

  SECTION("object update with a correct expected_revision succeeds and creates revision 2") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "v1")}).dump(),
                 "application/json");

    const auto response = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_update_mutation(object_id, 1, "v2")}).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);
    CHECK(nlohmann::json::parse(response->body).at("object_results")[0].at("revision") == 2);

    const auto current = client.Get("/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(nlohmann::json::parse(current->body).at("name") == "v2");
    CHECK(nlohmann::json::parse(current->body).at("revision") == 2);

    // Revision 1 remains retrievable, unchanged.
    const auto rev1 = client.Get("/repositories/" + repository_id + "/objects/" + object_id + "/revisions/1");
    CHECK(nlohmann::json::parse(rev1->body).at("name") == "v1");
  }

  SECTION("relationship update with a correct expected_revision succeeds and creates revision 2") {
    const std::string object_a = generate_uuid_v4();
    const std::string object_b = generate_uuid_v4();
    const std::string relationship_id = generate_uuid_v4();
    client.Post("/repositories/" + repository_id + "/commits",
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
                                            {"author", "wp-srv-011"}}},
    };
    const auto response = client.Post("/repositories/" + repository_id + "/commits",
                                        commit_body(generate_uuid_v4(), {update}).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto current = client.Get("/repositories/" + repository_id + "/relationships/" + relationship_id);
    CHECK(nlohmann::json::parse(current->body).at("relationship_type") == "documents");
    CHECK(nlohmann::json::parse(current->body).at("revision") == 2);
  }

  SECTION("stale expected_revision is rejected as a concurrency conflict, state unchanged") {
    const std::string object_id = generate_uuid_v4();
    client.Post("/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "v1")}).dump(),
                 "application/json");

    // Client A reads revision 1, Client B updates 1 -> 2 first.
    client.Post("/repositories/" + repository_id + "/commits",
                 commit_body(generate_uuid_v4(), {object_update_mutation(object_id, 1, "from-B")}).dump(),
                 "application/json");

    // Client A now submits its own update still believing revision 1 is current.
    const auto stale = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(generate_uuid_v4(), {object_update_mutation(object_id, 1, "from-A")}).dump(), "application/json");
    REQUIRE(stale != nullptr);
    CHECK(stale->status == 409);
    CHECK(nlohmann::json::parse(stale->body).at("error") == "CONCURRENCY_CONFLICT");

    // State reflects only Client B's successful update.
    const auto current = client.Get("/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(nlohmann::json::parse(current->body).at("name") == "from-B");
    CHECK(nlohmann::json::parse(current->body).at("revision") == 2);
  }

  SECTION("commit idempotent retry with identical content returns the original result, does not reapply") {
    const std::string object_id = generate_uuid_v4();
    const std::string operation_id = generate_uuid_v4();
    const auto body = commit_body(operation_id, {object_create_mutation(object_id, "Once")});

    const auto first = client.Post("/repositories/" + repository_id + "/commits", body.dump(), "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);
    const std::string commit_id = nlohmann::json::parse(first->body).at("commit_id").get<std::string>();

    const auto second = client.Post("/repositories/" + repository_id + "/commits", body.dump(), "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 201);
    CHECK(nlohmann::json::parse(second->body).at("commit_id") == commit_id);

    // Exactly one revision exists for this object -- the mutation was not reapplied.
    const auto current = client.Get("/repositories/" + repository_id + "/objects/" + object_id);
    CHECK(nlohmann::json::parse(current->body).at("revision") == 1);
  }

  SECTION("commit operation_id reused with different content is an idempotency conflict") {
    const std::string operation_id = generate_uuid_v4();
    const std::string object_id_1 = generate_uuid_v4();
    const std::string object_id_2 = generate_uuid_v4();

    const auto first = client.Post("/repositories/" + repository_id + "/commits",
                                     commit_body(operation_id, {object_create_mutation(object_id_1, "First")}).dump(),
                                     "application/json");
    REQUIRE(first != nullptr);
    CHECK(first->status == 201);

    const auto second = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(operation_id, {object_create_mutation(object_id_2, "Different")}).dump(), "application/json");
    REQUIRE(second != nullptr);
    CHECK(second->status == 409);
    CHECK(nlohmann::json::parse(second->body).at("error") == "IDEMPOTENCY_CONFLICT");
  }

  SECTION("a failed commit (validation) does not consume the operation_id -- retry after correction succeeds") {
    const std::string operation_id = generate_uuid_v4();
    const std::string object_a = generate_uuid_v4();
    const std::string bad_relationship = generate_uuid_v4();

    const auto failed = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(operation_id, {relationship_create_mutation(bad_relationship, object_a, generate_uuid_v4())})
            .dump(),
        "application/json");
    REQUIRE(failed != nullptr);
    CHECK(failed->status == 422);

    // Retry the SAME operation_id after fixing the request (creating the
    // object first) -- must succeed, not be blocked as a stale duplicate.
    const auto fixed = client.Post(
        "/repositories/" + repository_id + "/commits",
        commit_body(operation_id, {object_create_mutation(object_a, "Fixed")}).dump(), "application/json");
    REQUIRE(fixed != nullptr);
    CHECK(fixed->status == 201);
  }

  SECTION("commit audit association") {
    const std::string object_id = generate_uuid_v4();
    const auto response = client.Post("/repositories/" + repository_id + "/commits",
                                        commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "Audited")}).dump(),
                                        "application/json");
    const std::string commit_id = nlohmann::json::parse(response->body).at("commit_id").get<std::string>();

    pqxx::connection connection(
        oep::server_repository::common::Config{.database = test_database_config()}.database_connection_string());
    pqxx::work txn(connection);
    const auto result =
        txn.exec_params("SELECT COUNT(*) FROM audit_events WHERE commit_id = $1::uuid AND event_type = "
                          "'commit_applied'",
                          pqxx::params{commit_id});
    txn.commit();
    CHECK(result[0][0].as<int>() == 1);
  }

  SECTION("GET commit result returns the full recorded outcome") {
    const std::string object_id = generate_uuid_v4();
    const auto response = client.Post("/repositories/" + repository_id + "/commits",
                                        commit_body(generate_uuid_v4(), {object_create_mutation(object_id, "X")}).dump(),
                                        "application/json");
    const std::string commit_id = nlohmann::json::parse(response->body).at("commit_id").get<std::string>();

    const auto get_response = client.Get("/repositories/" + repository_id + "/commits/" + commit_id);
    REQUIRE(get_response != nullptr);
    CHECK(get_response->status == 200);
    const auto body = nlohmann::json::parse(get_response->body);
    CHECK(body.at("commit_id") == commit_id);
    CHECK(body.at("object_results")[0].at("object_id") == object_id);
  }

  server.stop();
}

TEST_CASE("Commit idempotency survives a restart", "[api][commit][database]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string operation_id = generate_uuid_v4();
  const std::string object_id = generate_uuid_v4();
  std::string repository_id;
  std::string original_commit_id;

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
        "/repositories", nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Restart Commit Repo"}}.dump(),
        "application/json");
    repository_id = nlohmann::json::parse(repo_response->body).at("id").get<std::string>();

    const auto commit_response =
        client.Post("/repositories/" + repository_id + "/commits",
                     commit_body(operation_id, {object_create_mutation(object_id, "Persisted")}).dump(),
                     "application/json");
    REQUIRE(commit_response != nullptr);
    REQUIRE(commit_response->status == 201);
    original_commit_id = nlohmann::json::parse(commit_response->body).at("commit_id").get<std::string>();
    server.stop();
  }

  {
    // A fresh store/server instance -- same durability argument as the
    // repository-creation restart test above.
    ServerRepositoryStore store(test_database_config());
    ServerConfig config;
    config.host = "127.0.0.1";
    config.port = 0;
    ApiServer server(config, kTestApiToken, store);
    REQUIRE(server.start());
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);

    const auto retry =
        client.Post("/repositories/" + repository_id + "/commits",
                     commit_body(operation_id, {object_create_mutation(object_id, "Persisted")}).dump(),
                     "application/json");
    REQUIRE(retry != nullptr);
    CHECK(retry->status == 201);
    CHECK(nlohmann::json::parse(retry->body).at("commit_id") == original_commit_id);

    const auto current = client.Get("/repositories/" + repository_id + "/objects/" + object_id);
    REQUIRE(current != nullptr);
    CHECK(current->status == 200);
    CHECK(nlohmann::json::parse(current->body).at("revision") == 1);

    server.stop();
  }
}

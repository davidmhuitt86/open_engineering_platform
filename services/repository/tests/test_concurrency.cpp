#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <thread>
#include <vector>

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

nlohmann::json object_create_mutation(const std::string& object_id, const std::string& name) {
  return nlohmann::json{
      {"kind", "object_create"},
      {"object_id", object_id},
      {"object", nlohmann::json{{"object_type", "document"}, {"name", name}, {"description", ""}, {"author", ""},
                                   {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
  };
}

nlohmann::json object_update_mutation(const std::string& object_id, std::int64_t expected_revision,
                                        const std::string& name) {
  return nlohmann::json{
      {"kind", "object_update"},
      {"object_id", object_id},
      {"expected_revision", expected_revision},
      {"object", nlohmann::json{{"object_type", "document"}, {"name", name}, {"description", ""}, {"author", ""},
                                   {"tags", nlohmann::json::array()}, {"content", ""}, {"version", "1.0.0"}}},
  };
}

}  // namespace

TEST_CASE("Concurrent writers targeting the same object: exactly one succeeds per revision, the rest conflict",
          "[api][concurrency][database]") {
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

  httplib::Client setup_client(config.host, server.bound_port());
  setup_client.set_bearer_token_auth(kTestApiToken);

  const std::string repository_id = [&] {
    const auto response = setup_client.Post(
        "/repositories", nlohmann::json{{"operation_id", generate_uuid_v4()}, {"name", "Concurrency Repo"}}.dump(),
        "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  }();

  const std::string object_id = [&] {
    const auto response =
        setup_client.Post("/repositories/" + repository_id + "/commits",
                            nlohmann::json{{"operation_id", generate_uuid_v4()},
                                             {"mutations", {object_create_mutation(generate_uuid_v4(), "concurrent")}}}
                                .dump(),
                            "application/json");
    return nlohmann::json::parse(response->body).at("object_results")[0].at("object_id").get<std::string>();
  }();

  // WP-SRV-011: "test concurrent writers rather than merely sequential
  // stale-revision behavior" -- N real OS threads, each with its own
  // httplib::Client, all racing to update the SAME object from the SAME
  // starting revision (1) at the same time.
  constexpr int kWriterCount = 8;
  std::atomic<int> success_count{0};
  std::atomic<int> conflict_count{0};
  std::vector<std::thread> writers;
  writers.reserve(kWriterCount);

  for (int i = 0; i < kWriterCount; ++i) {
    writers.emplace_back([&, i] {
      httplib::Client client(config.host, server.bound_port());
      client.set_bearer_token_auth(kTestApiToken);
      const auto response = client.Post(
          "/repositories/" + repository_id + "/commits",
          nlohmann::json{{"operation_id", generate_uuid_v4()},
                           {"mutations", {object_update_mutation(object_id, 1, "writer-" + std::to_string(i))}}}
              .dump(),
          "application/json");
      REQUIRE(response != nullptr);
      if (response->status == 201) {
        success_count++;
      } else if (response->status == 409) {
        conflict_count++;
      }
    });
  }
  for (auto& thread : writers) {
    thread.join();
  }

  // Exactly one writer wins revision 1 -> 2; every other concurrent
  // writer, having started from the same stale revision 1, MUST be
  // rejected as a conflict -- none of Client A's rejected mutations may
  // be applied (ADR-0004 SS10).
  CHECK(success_count == 1);
  CHECK(conflict_count == kWriterCount - 1);

  httplib::Client verify_client(config.host, server.bound_port());
  verify_client.set_bearer_token_auth(kTestApiToken);
  const auto current = verify_client.Get("/repositories/" + repository_id + "/objects/" + object_id);
  REQUIRE(current != nullptr);
  CHECK(current->status == 200);
  // Exactly one successful update landed -- revision advanced by exactly
  // one, not by kWriterCount (which would indicate every writer's
  // mutation was incorrectly applied instead of being serialized/
  // rejected).
  CHECK(nlohmann::json::parse(current->body).at("revision") == 2);

  server.stop();
}

#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <latch>
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

TEST_CASE(
    "WP-SRV-011A: concurrent writers race independent PostgreSQL transactions for the same object head, "
    "exactly one succeeds",
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

  // WP-SRV-011A correction: N real OS threads, each with its own
  // httplib::Client (and therefore, since WP-SRV-011A replaced the
  // store's single shared connection with a connection pool, its own
  // independent pqxx::connection/pqxx::work transaction on the server
  // side), all racing to update the SAME object from the SAME starting
  // revision (1). Each writer has its own operation_id (req. 13), so this
  // exercises the concurrency path, not the idempotency-replay path.
  //
  // A std::latch pair forces genuine overlap rather than hoping OS
  // scheduling happens to interleave the threads (req. 7): every writer
  // thread finishes constructing its client and counts down `ready`, then
  // blocks on `go`; only once all kWriterCount threads are blocked there
  // does the main thread release `go`, so every writer's HTTP request --
  // and therefore every writer's database transaction -- is issued only
  // after every other writer is already primed to issue theirs.
  constexpr int kWriterCount = 8;
  std::atomic<int> success_count{0};
  std::atomic<int> conflict_count{0};
  std::atomic<int> winning_writer{-1};
  std::latch ready(kWriterCount);
  std::latch go(1);
  std::vector<std::thread> writers;
  writers.reserve(kWriterCount);

  for (int i = 0; i < kWriterCount; ++i) {
    writers.emplace_back([&, i] {
      httplib::Client client(config.host, server.bound_port());
      client.set_bearer_token_auth(kTestApiToken);

      ready.count_down();
      go.wait();

      const auto response = client.Post(
          "/repositories/" + repository_id + "/commits",
          nlohmann::json{{"operation_id", generate_uuid_v4()},
                           {"mutations", {object_update_mutation(object_id, 1, "writer-" + std::to_string(i))}}}
              .dump(),
          "application/json");
      REQUIRE(response != nullptr);
      if (response->status == 201) {
        success_count++;
        winning_writer = i;
      } else if (response->status == 409) {
        conflict_count++;
      }
    });
  }
  ready.wait();
  go.count_down();
  for (auto& thread : writers) {
    thread.join();
  }

  // Exactly one writer wins revision 1 -> 2; every other concurrent
  // writer, having started from the same stale revision 1, MUST be
  // rejected as a conflict -- none of a rejected writer's mutations may
  // be applied (ADR-0004 SS10). This is now resolved by real competing
  // PostgreSQL transactions taking `SELECT ... FOR UPDATE` on the same
  // `object_heads` row (one blocks until the other commits, then observes
  // the now-stale `expected_revision` and is rejected), not by
  // application-level mutex serialization.
  CHECK(success_count == 1);
  CHECK(conflict_count == kWriterCount - 1);
  REQUIRE(winning_writer.load() >= 0);

  httplib::Client verify_client(config.host, server.bound_port());
  verify_client.set_bearer_token_auth(kTestApiToken);
  const auto current = verify_client.Get("/repositories/" + repository_id + "/objects/" + object_id);
  REQUIRE(current != nullptr);
  CHECK(current->status == 200);
  const auto current_body = nlohmann::json::parse(current->body);
  // Exactly one successful update landed -- revision advanced by exactly
  // one, not by kWriterCount (which would indicate every writer's
  // mutation was incorrectly applied instead of being serialized/
  // rejected).
  CHECK(current_body.at("revision") == 2);
  // The final state corresponds to exactly the one writer that received
  // 201 -- no rejected writer's content is present, whether as the final
  // state or anywhere in between (req. 11/12).
  CHECK(current_body.at("name") == "writer-" + std::to_string(winning_writer.load()));

  // The rejected writers' content must not appear even transiently in the
  // object's own revision history: only revision 1 (the original create)
  // and revision 2 (the single winner) may exist.
  const auto revision_1 = verify_client.Get("/repositories/" + repository_id + "/objects/" + object_id +
                                              "/revisions/1");
  REQUIRE(revision_1 != nullptr);
  CHECK(revision_1->status == 200);
  CHECK(nlohmann::json::parse(revision_1->body).at("name") == "concurrent");

  const auto revision_3 = verify_client.Get("/repositories/" + repository_id + "/objects/" + object_id +
                                              "/revisions/3");
  REQUIRE(revision_3 != nullptr);
  CHECK(revision_3->status == 404);

  server.stop();
}

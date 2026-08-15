#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <stop_token>
#include <thread>

#include <httplib.h>

#include "oep/acquisition/connectors/http_connector.hpp"

using namespace oep::acquisition::connectors;

namespace {

ConnectorConfig make_config() {
  ConnectorConfig config;
  config.connector_id = "conn-http-1";
  config.type = "http";
  config.name = "Test HTTP Connector";
  return config;
}

std::filesystem::path unique_temp_path() {
  static std::atomic<int> counter{0};
  return std::filesystem::temp_directory_path() /
         ("oep_http_connector_fetch_test_" + std::to_string(counter++) + ".bin");
}

std::string read_file(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

/// A real, local HTTP server -- not a fake/mock -- so `HttpConnector`'s
/// `fetch` is exercised against a genuine socket and a genuine HTTP
/// response, exactly like it would be against a real remote host,
/// without this test suite depending on live internet access or a
/// third-party service staying available. Mirrors `ApiServer::start`'s
/// own `bind_to_any_port`/`listen_after_bind`/`wait_until_ready` pattern
/// (`src/api/server.cpp`) so tests never collide on a fixed port.
class TestHttpServer {
 public:
  TestHttpServer() {
    server_.Get("/dataset.csv", [](const httplib::Request&, httplib::Response& res) {
      res.set_content("id,value\n1,42\n2,43\n", "text/csv");
    });
    server_.Get("/redirected-to", [](const httplib::Request&, httplib::Response& res) {
      res.set_content("redirected content\n", "text/plain");
    });
    server_.Get("/redirect", [](const httplib::Request&, httplib::Response& res) {
      res.set_redirect("/redirected-to");
    });
    server_.Get("/missing", [](const httplib::Request&, httplib::Response& res) { res.status = 404; });
    server_.Get("/slow", [](const httplib::Request&, httplib::Response& res) {
      std::this_thread::sleep_for(std::chrono::milliseconds(200));
      res.set_content("slow content\n", "text/plain");
    });

    port_ = server_.bind_to_any_port("127.0.0.1");
    REQUIRE(port_ > 0);
    thread_ = std::thread([this]() { server_.listen_after_bind(); });
    server_.wait_until_ready();
  }

  ~TestHttpServer() {
    server_.stop();
    if (thread_.joinable()) thread_.join();
  }

  [[nodiscard]] std::string origin() const { return "http://127.0.0.1:" + std::to_string(port_); }

 private:
  httplib::Server server_;
  std::thread thread_;
  int port_ = 0;
};

}  // namespace

TEST_CASE("HttpConnector.connect/disconnect toggle is_connected", "[connectors][http]") {
  HttpConnector connector(make_config());
  CHECK_FALSE(connector.is_connected());
  connector.connect();
  CHECK(connector.is_connected());
  connector.disconnect();
  CHECK_FALSE(connector.is_connected());
}

TEST_CASE("HttpConnector.capabilities parses the comma-separated 'capabilities' setting", "[connectors][http]") {
  auto config = make_config();
  config.settings["capabilities"] = "download_files";
  HttpConnector connector(config);
  CHECK(connector.capabilities() == std::set<std::string>{"download_files"});
}

TEST_CASE("HttpConnector.validate_configuration requires a non-empty id and type", "[connectors][http]") {
  ConnectorConfig config;
  HttpConnector empty(config);
  CHECK_FALSE(empty.validate_configuration());

  HttpConnector valid(make_config());
  CHECK(valid.validate_configuration());
}

TEST_CASE("HttpConnector.fetch retrieves a real file over a real HTTP connection", "[connectors][http]") {
  TestHttpServer test_server;
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  std::vector<std::pair<std::uint64_t, std::uint64_t>> progress_calls;
  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/dataset.csv";
  request.destination = destination;
  request.progress = [&](std::uint64_t current, std::uint64_t total) { progress_calls.emplace_back(current, total); };

  const auto result = connector.fetch(request);

  CHECK(result.success);
  CHECK_FALSE(result.error_message.has_value());
  CHECK(result.downloaded_file == destination);
  CHECK(result.mime_type == "text/csv");
  CHECK(result.bytes_transferred == std::string("id,value\n1,42\n2,43\n").size());
  CHECK(std::filesystem::exists(destination));
  CHECK(read_file(destination) == "id,value\n1,42\n2,43\n");
  CHECK_FALSE(progress_calls.empty());

  std::filesystem::remove(destination);
}

TEST_CASE("HttpConnector.fetch follows a real HTTP redirect", "[connectors][http]") {
  TestHttpServer test_server;
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/redirect";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK(result.success);
  CHECK(read_file(destination) == "redirected content\n");

  std::filesystem::remove(destination);
}

TEST_CASE("HttpConnector.fetch fails with a descriptive error on a real 404", "[connectors][http]") {
  TestHttpServer test_server;
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/missing";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("404") != std::string::npos);
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("HttpConnector.fetch rejects a non-http(s) source_uri without touching the network", "[connectors][http]") {
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "stub://example/artifact.pdf";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("HttpConnector.fetch respects overwrite=false against an existing destination", "[connectors][http]") {
  TestHttpServer test_server;
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  {
    std::ofstream seed(destination);
    seed << "pre-existing";
  }

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/dataset.csv";
  request.destination = destination;
  request.overwrite = false;

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  CHECK(read_file(destination) == "pre-existing");

  std::filesystem::remove(destination);
}

TEST_CASE("HttpConnector.fetch honors an already-cancelled stop_token before starting", "[connectors][http]") {
  TestHttpServer test_server;
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  std::stop_source source;
  source.request_stop();

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/dataset.csv";
  request.destination = destination;
  request.cancellation = source.get_token();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("HttpConnector.fetch can be cancelled mid-transfer via a real stop_token", "[connectors][http]") {
  TestHttpServer test_server;
  HttpConnector connector(make_config());

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  std::stop_source source;
  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/slow";
  request.destination = destination;
  request.cancellation = source.get_token();
  request.progress = [&](std::uint64_t, std::uint64_t) { source.request_stop(); };

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("HttpConnector.fetch reports failure when configured via fetch_outcome=failure", "[connectors][http]") {
  auto config = make_config();
  config.settings["fetch_outcome"] = "failure";
  HttpConnector connector(config);

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "http://127.0.0.1:1/unused";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK_FALSE(std::filesystem::exists(destination));
}

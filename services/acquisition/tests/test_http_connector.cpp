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

// ADR-0003: production destination validation (the default -- see
// `make_config` above) rejects loopback, which is exactly what
// `TestHttpServer` below binds to. Tests that exercise fetch/redirect/
// error-handling *mechanics* (not the destination policy itself) use
// this config instead, mirroring this connector's own documented,
// test-only `"allow_private_destinations"` escape hatch -- never set by
// the real `"http-source"` connector `main.cpp` registers (see the
// "production defaults" test below, which asserts that directly).
ConnectorConfig make_local_test_config() {
  auto config = make_config();
  config.settings["allow_private_destinations"] = "true";
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
    // ADR-0003 test fixtures -- a redirect Location this connector must
    // reject (not a real, followable scheme), an infinite redirect loop
    // (exercises max_redirects), and a redirect to a hostname reserved
    // by RFC 2606 to never resolve (exercises "each hop is re-resolved").
    server_.Get("/redirect-to-unsupported-scheme", [](const httplib::Request&, httplib::Response& res) {
      res.status = 302;
      res.set_header("Location", "ftp://example.com/file");
    });
    server_.Get("/redirect-loop", [](const httplib::Request&, httplib::Response& res) {
      res.status = 302;
      res.set_header("Location", "/redirect-loop");
    });
    server_.Get("/redirect-to-unresolvable", [](const httplib::Request&, httplib::Response& res) {
      res.status = 302;
      res.set_header("Location", "http://this-host-does-not-exist.invalid/artifact");
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
  HttpConnector connector(make_local_test_config());

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
  HttpConnector connector(make_local_test_config());

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
  HttpConnector connector(make_local_test_config());

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
  HttpConnector connector(make_local_test_config());

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
  HttpConnector connector(make_local_test_config());

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
  HttpConnector connector(make_local_test_config());

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

// ---------------------------------------------------------------------
// ADR-0003 (HttpConnector Security, Scope, and SSRF Resolution): the
// connector's actual destination-validation contract. Every test below
// uses `make_config()` (the real default -- no `allow_private_destinations`
// override), proving these are rejected by the connector *itself*,
// deterministically, before any socket is ever opened -- `getaddrinfo`
// resolves a literal IP address without any real DNS query or network
// access, so none of these depend on internet access or a live server.
// ---------------------------------------------------------------------

TEST_CASE("HttpConnector.fetch rejects an IPv4 loopback destination by default", "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "http://127.0.0.1:80/secret";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("disallowed") != std::string::npos);
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("HttpConnector.fetch rejects 0.0.0.0 by default", "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "http://0.0.0.0/secret";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("disallowed") != std::string::npos);
}

TEST_CASE("HttpConnector.fetch rejects an IPv6 loopback destination by default", "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "http://[::1]:80/secret";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("disallowed") != std::string::npos);
}

TEST_CASE("HttpConnector.fetch rejects an RFC1918 private IPv4 destination by default", "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  for (const std::string& host : {"10.1.2.3", "172.16.0.5", "192.168.1.1"}) {
    AcquisitionRequest request;
    request.job_id = "job-1";
    request.source_uri = "http://" + host + "/secret";
    request.destination = unique_temp_path();

    const auto result = connector.fetch(request);

    CHECK_FALSE(result.success);
    REQUIRE(result.error_message.has_value());
    CHECK(result.error_message->find("disallowed") != std::string::npos);
  }
}

TEST_CASE("HttpConnector.fetch rejects a link-local IPv4 destination by default (covers the cloud metadata address)",
          "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  AcquisitionRequest request;
  request.job_id = "job-1";
  // 169.254.169.254 is the well-known cloud-provider instance-metadata
  // address -- it is simply a 169.254.0.0/16 link-local address, and is
  // rejected by that generic rule rather than a special case.
  request.source_uri = "http://169.254.169.254/latest/meta-data/";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("disallowed") != std::string::npos);
}

TEST_CASE("HttpConnector.fetch rejects an IPv4-mapped IPv6 loopback destination by default", "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  AcquisitionRequest request;
  request.job_id = "job-1";
  // ::ffff:127.0.0.1 -- an IPv4-mapped IPv6 literal, one classic
  // "alternate representation" SSRF bypass technique.
  request.source_uri = "http://[::ffff:127.0.0.1]:80/secret";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("disallowed") != std::string::npos);
}

TEST_CASE("HttpConnector.fetch rejects a URL with userinfo in the authority", "[connectors][http][ssrf]") {
  HttpConnector connector(make_config());
  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "http://trusted.example.com@127.0.0.1/secret";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
}

TEST_CASE("HttpConnector.fetch rejects a redirect to an unsupported/invalid location", "[connectors][http][ssrf]") {
  // Proves redirect destinations are independently parsed/validated --
  // not simply followed -- using a real local server (allowed here only
  // to reach the server itself; the redirect target below is rejected
  // regardless of that setting, since parse_url/resolve_redirect run
  // unconditionally before any destination-class check).
  TestHttpServer test_server;
  HttpConnector connector(make_local_test_config());

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/redirect-to-unsupported-scheme";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
}

TEST_CASE("HttpConnector.fetch rejects a redirect chain exceeding max_redirects", "[connectors][http][ssrf]") {
  TestHttpServer test_server;
  HttpConnector connector(make_local_test_config());

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/redirect-loop";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("redirect") != std::string::npos);
}

TEST_CASE("HttpConnector.fetch rejects a response exceeding max_response_bytes", "[connectors][http][ssrf]") {
  TestHttpServer test_server;
  auto config = make_local_test_config();
  config.settings["max_response_bytes"] = "10";  // far smaller than /dataset.csv's real body
  HttpConnector connector(config);

  const auto destination = unique_temp_path();
  std::filesystem::remove(destination);

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/dataset.csv";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("maximum allowed size") != std::string::npos);
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("HttpConnector.fetch's redirect-target resolution is genuinely re-run per hop, not skipped",
          "[connectors][http][ssrf]") {
  // A redirect to a hostname that cannot resolve at all proves the
  // connector actually re-validates/re-resolves each redirect target
  // (rather than, say, trusting the first hop's validation for every
  // subsequent one) -- ".invalid" is reserved by RFC 2606 to never
  // resolve, so this is deterministic without depending on real DNS
  // behavior for any other name.
  TestHttpServer test_server;
  HttpConnector connector(make_local_test_config());

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = test_server.origin() + "/redirect-to-unresolvable";
  request.destination = unique_temp_path();

  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("Could not resolve host") != std::string::npos);
}

TEST_CASE("main.cpp's real 'http-source' connector registration does not opt out of destination validation",
          "[connectors][http][ssrf]") {
  // A literal, direct check against this repository's own real startup
  // registration (src/app/main.cpp) -- not a re-statement of the
  // connector's own default, but a guard against a future edit to
  // main.cpp silently adding `allow_private_destinations` to the live
  // "http-source" connector's settings. Walks upward from the test
  // binary's own working directory (which varies by how/where it is
  // invoked) looking for the marker path, rather than guessing a fixed
  // number of ".." hops.
  std::filesystem::path search_dir = std::filesystem::current_path();
  std::filesystem::path main_cpp_path;
  for (int i = 0; i < 8; ++i) {
    auto candidate = search_dir / "src" / "app" / "main.cpp";
    if (std::filesystem::exists(candidate)) {
      main_cpp_path = candidate;
      break;
    }
    if (search_dir.has_parent_path() && search_dir.parent_path() != search_dir) {
      search_dir = search_dir.parent_path();
    } else {
      break;
    }
  }
  REQUIRE_FALSE(main_cpp_path.empty());
  std::ifstream main_cpp(main_cpp_path);
  REQUIRE(main_cpp.is_open());
  std::ostringstream buffer;
  buffer << main_cpp.rdbuf();
  const std::string contents = buffer.str();

  const auto http_source_pos = contents.find("\"http-source\"");
  REQUIRE(http_source_pos != std::string::npos);
  const auto next_registration = contents.find("register_connector", http_source_pos + 1);
  const auto section_end = next_registration == std::string::npos ? contents.size() : next_registration;
  const std::string section = contents.substr(http_source_pos, section_end - http_source_pos);

  CHECK(section.find("allow_private_destinations") == std::string::npos);
}

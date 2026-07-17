#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <stop_token>
#include <vector>

#include "oep/acquisition/connectors/stub_connector.hpp"

using namespace oep::acquisition::connectors;

namespace {

ConnectorConfig make_config() {
  ConnectorConfig config;
  config.connector_id = "conn-1";
  config.type = "stub";
  config.name = "Test Connector";
  return config;
}

std::filesystem::path unique_temp_path() {
  static std::atomic<int> counter{0};
  return std::filesystem::temp_directory_path() /
         ("oep_stub_connector_fetch_test_" + std::to_string(counter++) + ".bin");
}

std::string read_file(const std::filesystem::path& path) {
  std::ifstream stream(path);
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

}  // namespace

TEST_CASE("StubConnector.connect/disconnect toggle is_connected", "[connectors][stub]") {
  StubConnector connector(make_config());
  CHECK_FALSE(connector.is_connected());

  connector.connect();
  CHECK(connector.is_connected());

  connector.disconnect();
  CHECK_FALSE(connector.is_connected());
}

TEST_CASE("StubConnector.capabilities parses the comma-separated 'capabilities' setting",
          "[connectors][stub]") {
  auto config = make_config();
  config.settings["capabilities"] = "download_files,search";
  StubConnector connector(config);

  const auto capabilities = connector.capabilities();
  CHECK(capabilities.size() == 2);
  CHECK(capabilities.contains("download_files"));
  CHECK(capabilities.contains("search"));
}

TEST_CASE("StubConnector.capabilities is empty when the setting is absent", "[connectors][stub]") {
  StubConnector connector(make_config());
  CHECK(connector.capabilities().empty());
}

TEST_CASE("StubConnector.health_check defaults to Healthy", "[connectors][stub]") {
  StubConnector connector(make_config());
  const auto result = connector.health_check();
  CHECK(result.status == HealthStatus::Healthy);
  CHECK_FALSE(result.message.empty());
  CHECK_FALSE(result.checked_at.empty());
}

TEST_CASE("StubConnector.health_check honors the 'health_status' setting", "[connectors][stub]") {
  auto unhealthy_config = make_config();
  unhealthy_config.settings["health_status"] = "unhealthy";
  CHECK(StubConnector(unhealthy_config).health_check().status == HealthStatus::Unhealthy);

  auto unknown_config = make_config();
  unknown_config.settings["health_status"] = "unknown";
  CHECK(StubConnector(unknown_config).health_check().status == HealthStatus::Unknown);
}

TEST_CASE("StubConnector.validate_configuration requires a non-empty id and type", "[connectors][stub]") {
  CHECK(StubConnector(make_config()).validate_configuration());

  auto missing_id = make_config();
  missing_id.connector_id.clear();
  CHECK_FALSE(StubConnector(missing_id).validate_configuration());

  auto missing_type = make_config();
  missing_type.type.clear();
  CHECK_FALSE(StubConnector(missing_type).validate_configuration());
}

TEST_CASE("StubConnector.capabilities is unaffected by connect/disconnect (immutable post-construction)",
          "[connectors][stub][validation]") {
  auto config = make_config();
  config.settings["capabilities"] = "download_files";
  StubConnector connector(config);

  const auto before = connector.capabilities();
  connector.connect();
  connector.disconnect();
  const auto after = connector.capabilities();

  // WORK_PACKAGE-005: "Capability definitions shall be immutable after
  // registration" -- IConnector exposes no setter for capabilities, so
  // this is satisfied by the interface's shape; this test only confirms
  // no other operation on the connector has a side effect on it.
  CHECK(before == after);
}

// ADR-0008: Connector Content Retrieval Interface.

TEST_CASE("StubConnector.fetch writes the destination file and reports a successful result",
          "[connectors][stub][fetch]") {
  StubConnector connector(make_config());
  const auto destination = unique_temp_path();

  AcquisitionRequest request;
  request.job_id = "job-1";
  request.source_uri = "stub://example/artifact";
  request.destination = destination;

  const auto result = connector.fetch(request);

  CHECK(result.success);
  CHECK_FALSE(result.error_message.has_value());
  CHECK(result.downloaded_file == destination);
  CHECK(result.bytes_transferred > 0);
  CHECK(result.mime_type == "text/plain");
  CHECK_FALSE(result.checksum.empty());
  REQUIRE(std::filesystem::exists(destination));
  CHECK_FALSE(read_file(destination).empty());

  std::filesystem::remove(destination);
}

TEST_CASE("StubConnector.fetch honors the 'fetch_mime_type' setting", "[connectors][stub][fetch]") {
  auto config = make_config();
  config.settings["fetch_mime_type"] = "application/pdf";
  StubConnector connector(config);
  const auto destination = unique_temp_path();

  AcquisitionRequest request;
  request.destination = destination;
  const auto result = connector.fetch(request);

  CHECK(result.mime_type == "application/pdf");
  std::filesystem::remove(destination);
}

TEST_CASE("StubConnector.fetch reports the same checksum for identical content",
          "[connectors][stub][fetch]") {
  StubConnector first(make_config());
  StubConnector second(make_config());
  const auto first_destination = unique_temp_path();
  const auto second_destination = unique_temp_path();

  AcquisitionRequest first_request;
  first_request.destination = first_destination;
  AcquisitionRequest second_request;
  second_request.destination = second_destination;

  const auto first_result = first.fetch(first_request);
  const auto second_result = second.fetch(second_request);

  CHECK(first_result.checksum == second_result.checksum);

  std::filesystem::remove(first_destination);
  std::filesystem::remove(second_destination);
}

TEST_CASE("StubConnector.fetch honors the 'fetch_outcome' setting", "[connectors][stub][fetch]") {
  auto config = make_config();
  config.settings["fetch_outcome"] = "failure";
  StubConnector connector(config);
  const auto destination = unique_temp_path();

  AcquisitionRequest request;
  request.destination = destination;
  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("StubConnector.fetch fails when the destination exists and overwrite is false",
          "[connectors][stub][fetch]") {
  StubConnector connector(make_config());
  const auto destination = unique_temp_path();
  {
    std::ofstream existing(destination);
    existing << "already here";
  }

  AcquisitionRequest request;
  request.destination = destination;
  request.overwrite = false;
  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(read_file(destination) == "already here");  // untouched

  std::filesystem::remove(destination);
}

TEST_CASE("StubConnector.fetch overwrites an existing destination when overwrite is true",
          "[connectors][stub][fetch]") {
  StubConnector connector(make_config());
  const auto destination = unique_temp_path();
  {
    std::ofstream existing(destination);
    existing << "already here";
  }

  AcquisitionRequest request;
  request.destination = destination;
  request.overwrite = true;
  const auto result = connector.fetch(request);

  CHECK(result.success);
  CHECK(read_file(destination) != "already here");

  std::filesystem::remove(destination);
}

TEST_CASE("StubConnector.fetch fails immediately when the cancellation token is already cancelled",
          "[connectors][stub][fetch]") {
  StubConnector connector(make_config());
  const auto destination = unique_temp_path();

  std::stop_source stop_source;
  stop_source.request_stop();

  AcquisitionRequest request;
  request.destination = destination;
  request.cancellation = stop_source.get_token();
  const auto result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK_FALSE(std::filesystem::exists(destination));
}

TEST_CASE("StubConnector.fetch invokes the progress callback with start and end totals",
          "[connectors][stub][fetch]") {
  StubConnector connector(make_config());
  const auto destination = unique_temp_path();

  std::vector<std::pair<std::uint64_t, std::uint64_t>> calls;
  AcquisitionRequest request;
  request.destination = destination;
  request.progress = [&calls](std::uint64_t transferred, std::uint64_t total) {
    calls.emplace_back(transferred, total);
  };

  const auto result = connector.fetch(request);

  REQUIRE(calls.size() == 2);
  CHECK(calls.front().first == 0);
  CHECK(calls.back().first == calls.back().second);
  CHECK(calls.back().second == result.bytes_transferred);

  std::filesystem::remove(destination);
}

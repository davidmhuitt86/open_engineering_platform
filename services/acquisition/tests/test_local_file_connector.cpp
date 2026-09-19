#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>
#include <sstream>

#include "oep/acquisition/connectors/local_file_connector.hpp"

using namespace oep::acquisition::connectors;

namespace {

ConnectorConfig make_config() {
  ConnectorConfig config;
  config.connector_id = "local-file";
  config.type = "local-file";
  config.name = "Test Local File Connector";
  return config;
}

std::atomic<int> counter{0};

std::filesystem::path unique_temp_path(const std::string& suffix = ".bin") {
  return std::filesystem::temp_directory_path() /
         ("oep_local_file_connector_test_" + std::to_string(counter++) + suffix);
}

std::string read_file(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

// WP-EAM-005 §11 / Phase 14: every test in this file cleans up both the
// source fixture and the destination staging file it creates, and never
// leaves either behind on assertion failure (RAII).
class TempFile {
 public:
  explicit TempFile(std::string content = "", std::string suffix = ".pdf")
      : path_(unique_temp_path(suffix)) {
    // Always create the file, even for empty content -- an "empty file"
    // fixture must be a real zero-byte file on disk, not a nonexistent
    // path (which would exercise the missing-file branch instead).
    std::ofstream stream(path_, std::ios::binary);
    stream << content;
  }
  ~TempFile() {
    std::error_code ignored;
    std::filesystem::remove(path_, ignored);
  }
  TempFile(const TempFile&) = delete;
  TempFile& operator=(const TempFile&) = delete;

  const std::filesystem::path& path() const { return path_; }

 private:
  std::filesystem::path path_;
};

}  // namespace

TEST_CASE("LocalFileConnector.connect/disconnect toggle is_connected", "[connectors][local_file]") {
  LocalFileConnector connector(make_config());
  CHECK_FALSE(connector.is_connected());
  connector.connect();
  CHECK(connector.is_connected());
  connector.disconnect();
  CHECK_FALSE(connector.is_connected());
}

TEST_CASE("LocalFileConnector.validate_configuration requires connector_id and type",
          "[connectors][local_file]") {
  CHECK(LocalFileConnector(make_config()).validate_configuration());

  ConnectorConfig missing_id = make_config();
  missing_id.connector_id.clear();
  CHECK_FALSE(LocalFileConnector(missing_id).validate_configuration());
}

TEST_CASE("LocalFileConnector.fetch copies real bytes from source_uri to destination unchanged",
          "[connectors][local_file]") {
  const std::string content = "%PDF-1.4 fake engineering document contents\n";
  TempFile source(content);
  const auto destination = unique_temp_path(".staged");

  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = source.path().string();
  request.destination = destination;

  const AcquisitionResult result = connector.fetch(request);

  CHECK(result.success);
  CHECK(result.bytes_transferred == content.size());
  CHECK(std::filesystem::exists(destination));
  CHECK(read_file(destination) == content);

  // WP-EAM-005 §4/§11: the original source file must remain completely
  // untouched -- still exists, still has its original content.
  CHECK(std::filesystem::exists(source.path()));
  CHECK(read_file(source.path()) == content);

  std::error_code ignored;
  std::filesystem::remove(destination, ignored);
}

TEST_CASE("LocalFileConnector.fetch rejects a relative source_uri", "[connectors][local_file]") {
  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = "relative/path.pdf";
  request.destination = unique_temp_path();

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("absolute") != std::string::npos);
  CHECK_FALSE(std::filesystem::exists(request.destination));
}

TEST_CASE("LocalFileConnector.fetch fails cleanly when the source file does not exist",
          "[connectors][local_file]") {
  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = unique_temp_path(".missing").string();
  request.destination = unique_temp_path();

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK_FALSE(std::filesystem::exists(request.destination));
}

TEST_CASE("LocalFileConnector.fetch rejects a directory as source_uri", "[connectors][local_file]") {
  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = std::filesystem::temp_directory_path().string();
  request.destination = unique_temp_path();

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("regular file") != std::string::npos);
}

TEST_CASE("LocalFileConnector.fetch rejects an empty source file", "[connectors][local_file]") {
  TempFile empty_source;  // no content written
  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = empty_source.path().string();
  request.destination = unique_temp_path();

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("empty") != std::string::npos);
}

TEST_CASE("LocalFileConnector.fetch rejects a source file exceeding max_file_bytes",
          "[connectors][local_file]") {
  TempFile source(std::string(100, 'x'));

  ConnectorConfig config = make_config();
  config.settings["max_file_bytes"] = "10";
  LocalFileConnector connector(config);

  AcquisitionRequest request;
  request.source_uri = source.path().string();
  request.destination = unique_temp_path();

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("maximum accepted size") != std::string::npos);
  CHECK_FALSE(std::filesystem::exists(request.destination));
}

TEST_CASE("LocalFileConnector.fetch respects overwrite=false against an existing destination",
          "[connectors][local_file]") {
  TempFile source("real content");
  const auto destination = unique_temp_path();
  {
    std::ofstream stream(destination);
    stream << "pre-existing";
  }

  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = source.path().string();
  request.destination = destination;
  request.overwrite = false;

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  CHECK(read_file(destination) == "pre-existing");

  std::error_code ignored;
  std::filesystem::remove(destination, ignored);
}

TEST_CASE("LocalFileConnector.fetch respects cancellation requested before it starts",
          "[connectors][local_file]") {
  TempFile source("content");
  std::stop_source stop;
  stop.request_stop();

  LocalFileConnector connector(make_config());
  AcquisitionRequest request;
  request.source_uri = source.path().string();
  request.destination = unique_temp_path();
  request.cancellation = stop.get_token();

  const AcquisitionResult result = connector.fetch(request);

  CHECK_FALSE(result.success);
  CHECK_FALSE(std::filesystem::exists(request.destination));
}

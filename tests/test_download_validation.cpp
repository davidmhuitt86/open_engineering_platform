#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/downloads/validation.hpp"

using namespace oep::acquisition::downloads;

namespace {

nlohmann::json valid_body() {
  return nlohmann::json{
      {"job_id", "11111111-1111-1111-1111-111111111111"},
      {"connector_id", "example-stub"},
      {"source_uri", "stub://example/artifact.pdf"},
  };
}

}  // namespace

TEST_CASE("parse_and_validate_start accepts a fully-populated body", "[downloads][validation]") {
  const auto request = parse_and_validate_start(valid_body());

  CHECK(request.job_id == "11111111-1111-1111-1111-111111111111");
  CHECK(request.connector_id == "example-stub");
  CHECK(request.source_uri == "stub://example/artifact.pdf");
  CHECK(request.file_name.empty());
}

TEST_CASE("parse_and_validate_start accepts an optional file_name", "[downloads][validation]") {
  auto body = valid_body();
  body["file_name"] = "custom.pdf";

  const auto request = parse_and_validate_start(body);
  CHECK(request.file_name == "custom.pdf");
}

TEST_CASE("parse_and_validate_start rejects a missing job_id", "[downloads][validation]") {
  auto body = valid_body();
  body.erase("job_id");

  CHECK_THROWS_AS(parse_and_validate_start(body), ValidationError);
}

TEST_CASE("parse_and_validate_start rejects a missing connector_id", "[downloads][validation]") {
  auto body = valid_body();
  body.erase("connector_id");

  CHECK_THROWS_AS(parse_and_validate_start(body), ValidationError);
}

TEST_CASE("parse_and_validate_start rejects a missing source_uri", "[downloads][validation]") {
  auto body = valid_body();
  body.erase("source_uri");

  CHECK_THROWS_AS(parse_and_validate_start(body), ValidationError);
}

TEST_CASE("parse_and_validate_start reports every violation at once", "[downloads][validation]") {
  const nlohmann::json body = nlohmann::json::object();

  try {
    [[maybe_unused]] const auto ignored = parse_and_validate_start(body);
    FAIL("expected ValidationError");
  } catch (const ValidationError& error) {
    CHECK(error.violations().size() == 3);  // job_id, connector_id, source_uri
  }
}

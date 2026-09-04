#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/acquisition/validation.hpp"

using namespace oep::acquisition::acquisition;

namespace {

nlohmann::json valid_create_body() {
  return nlohmann::json{
      {"name", "Acquire IEEE Standard 802.11"},
      {"source_id", "11111111-1111-1111-1111-111111111111"},
      {"description", "Pull the latest revision."},
      {"priority", 2},
      {"requested_by", "jdoe"},
  };
}

nlohmann::json valid_update_body() {
  auto body = valid_create_body();
  body["status"] = "queued";
  return body;
}

}  // namespace

TEST_CASE("parse_and_validate_create accepts a fully-populated body and forces status=Created",
          "[jobs][validation]") {
  const AcquisitionJob job = parse_and_validate_create(valid_create_body());

  CHECK(job.id.empty());
  CHECK(job.created_at.empty());
  CHECK(job.name == "Acquire IEEE Standard 802.11");
  CHECK(job.source_id == "11111111-1111-1111-1111-111111111111");
  CHECK(job.priority == JobPriority::High);
  CHECK(job.status == JobStatus::Created);
  CHECK_FALSE(job.started_at.has_value());
  CHECK_FALSE(job.completed_at.has_value());
  CHECK_FALSE(job.error_message.has_value());
}

TEST_CASE("parse_and_validate_create ignores a client-supplied status", "[jobs][validation]") {
  auto body = valid_create_body();
  body["status"] = "running";

  const AcquisitionJob job = parse_and_validate_create(body);
  CHECK(job.status == JobStatus::Created);
}

TEST_CASE("parse_and_validate_create rejects a missing Name", "[jobs][validation]") {
  auto body = valid_create_body();
  body.erase("name");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects a missing Source ID", "[jobs][validation]") {
  auto body = valid_create_body();
  body.erase("source_id");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects a missing Priority", "[jobs][validation]") {
  auto body = valid_create_body();
  body.erase("priority");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects a Priority out of range", "[jobs][validation]") {
  auto body = valid_create_body();
  body["priority"] = 9;

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create reports every violation at once", "[jobs][validation]") {
  const nlohmann::json body = nlohmann::json::object();

  try {
    [[maybe_unused]] const auto ignored = parse_and_validate_create(body);
    FAIL("expected ValidationError");
  } catch (const ValidationError& error) {
    CHECK(error.violations().size() == 3);  // name, source_id, priority
  }
}

TEST_CASE("parse_and_validate_update requires Status in addition to Name/Source ID/Priority",
          "[jobs][validation]") {
  auto body = valid_create_body();  // no "status"
  AcquisitionJob existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  CHECK_THROWS_AS(parse_and_validate_update(body, existing), ValidationError);
}

TEST_CASE("parse_and_validate_update rejects an unrecognized Status", "[jobs][validation]") {
  auto body = valid_update_body();
  body["status"] = "not-a-real-status";
  AcquisitionJob existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  CHECK_THROWS_AS(parse_and_validate_update(body, existing), ValidationError);
}

TEST_CASE("parse_and_validate_update preserves id and created_at when the body omits them",
          "[jobs][validation]") {
  AcquisitionJob existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  const AcquisitionJob updated = parse_and_validate_update(valid_update_body(), existing);
  CHECK(updated.id == "existing-id");
  CHECK(updated.created_at == "2026-01-01T00:00:00Z");
  CHECK(updated.status == JobStatus::Queued);
}

TEST_CASE("parse_and_validate_update rejects an attempt to change the immutable id", "[jobs][validation]") {
  AcquisitionJob existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  auto body = valid_update_body();
  body["id"] = "a-different-id";

  CHECK_THROWS_AS(parse_and_validate_update(body, existing), ValidationError);
}

TEST_CASE("parse_and_validate_update rejects an attempt to change the immutable created_at",
          "[jobs][validation]") {
  AcquisitionJob existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  auto body = valid_update_body();
  body["created_at"] = "2030-01-01T00:00:00Z";

  CHECK_THROWS_AS(parse_and_validate_update(body, existing), ValidationError);
}

TEST_CASE("parse_and_validate_update accepts started_at/completed_at/error_message", "[jobs][validation]") {
  AcquisitionJob existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  auto body = valid_update_body();
  body["status"] = "failed";
  body["started_at"] = "2026-01-01T01:00:00Z";
  body["completed_at"] = "2026-01-01T02:00:00Z";
  body["error_message"] = "Connection timed out.";

  const AcquisitionJob updated = parse_and_validate_update(body, existing);
  REQUIRE(updated.started_at.has_value());
  CHECK(*updated.started_at == "2026-01-01T01:00:00Z");
  REQUIRE(updated.completed_at.has_value());
  CHECK(*updated.completed_at == "2026-01-01T02:00:00Z");
  REQUIRE(updated.error_message.has_value());
  CHECK(*updated.error_message == "Connection timed out.");
}

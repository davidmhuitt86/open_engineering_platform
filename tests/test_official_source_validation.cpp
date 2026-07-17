#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/registry/validation.hpp"

using namespace oep::acquisition::registry;

namespace {

nlohmann::json valid_body() {
  return nlohmann::json{
      {"name", "Example Standards Body"},
      {"organization", "Example Org"},
      {"base_url", "https://example.org"},
      {"description", "A test source."},
      {"country", "US"},
      {"language", "en"},
      {"category", "standards"},
      {"trust_level", 5},
      {"status", "active"},
      {"authentication_type", "api_key"},
  };
}

}  // namespace

TEST_CASE("parse_and_validate_create accepts a fully-populated body", "[registry][validation]") {
  const OfficialSource source = parse_and_validate_create(valid_body());

  CHECK(source.id.empty());
  CHECK(source.created_at.empty());
  CHECK(source.name == "Example Standards Body");
  CHECK(source.base_url == "https://example.org");
  CHECK(source.trust_level == TrustLevel::Authoritative);
  CHECK(source.status == SourceStatus::Active);
  CHECK(source.authentication_type == AuthenticationType::ApiKey);
}

TEST_CASE("parse_and_validate_create defaults authentication_type to None when omitted",
          "[registry][validation]") {
  auto body = valid_body();
  body.erase("authentication_type");

  const OfficialSource source = parse_and_validate_create(body);
  CHECK(source.authentication_type == AuthenticationType::None);
}

TEST_CASE("parse_and_validate_create rejects a missing Name", "[registry][validation]") {
  auto body = valid_body();
  body.erase("name");

  try {
    [[maybe_unused]] const auto ignored = parse_and_validate_create(body);
    FAIL("expected ValidationError");
  } catch (const ValidationError& error) {
    CHECK(error.violations().size() == 1);
    CHECK(error.violations().front() == "Name is required.");
  }
}

TEST_CASE("parse_and_validate_create rejects a missing Base URL", "[registry][validation]") {
  auto body = valid_body();
  body.erase("base_url");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects a missing Trust Level", "[registry][validation]") {
  auto body = valid_body();
  body.erase("trust_level");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects a Trust Level out of range", "[registry][validation]") {
  auto body = valid_body();
  body["trust_level"] = 9;

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects a missing Status", "[registry][validation]") {
  auto body = valid_body();
  body.erase("status");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects an unrecognized Status", "[registry][validation]") {
  auto body = valid_body();
  body["status"] = "not-a-real-status";

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create rejects an unrecognized Authentication Type", "[registry][validation]") {
  auto body = valid_body();
  body["authentication_type"] = "carrier_pigeon";

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create reports every violation at once", "[registry][validation]") {
  const nlohmann::json body = nlohmann::json::object();

  try {
    [[maybe_unused]] const auto ignored = parse_and_validate_create(body);
    FAIL("expected ValidationError");
  } catch (const ValidationError& error) {
    CHECK(error.violations().size() == 4);  // name, base_url, trust_level, status
  }
}

TEST_CASE("parse_and_validate_update preserves id and created_at when the body omits them",
          "[registry][validation]") {
  OfficialSource existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  const OfficialSource updated = parse_and_validate_update(valid_body(), existing);
  CHECK(updated.id == "existing-id");
  CHECK(updated.created_at == "2026-01-01T00:00:00Z");
}

TEST_CASE("parse_and_validate_update allows a body that echoes back the same id", "[registry][validation]") {
  OfficialSource existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  auto body = valid_body();
  body["id"] = "existing-id";

  CHECK_NOTHROW(parse_and_validate_update(body, existing));
}

TEST_CASE("parse_and_validate_update rejects an attempt to change the immutable id", "[registry][validation]") {
  OfficialSource existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  auto body = valid_body();
  body["id"] = "a-different-id";

  CHECK_THROWS_AS(parse_and_validate_update(body, existing), ValidationError);
}

TEST_CASE("parse_and_validate_update rejects an attempt to change the immutable created_at",
          "[registry][validation]") {
  OfficialSource existing;
  existing.id = "existing-id";
  existing.created_at = "2026-01-01T00:00:00Z";

  auto body = valid_body();
  body["created_at"] = "2030-01-01T00:00:00Z";

  CHECK_THROWS_AS(parse_and_validate_update(body, existing), ValidationError);
}

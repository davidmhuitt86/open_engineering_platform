#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/metadata/validation.hpp"

using namespace oep::acquisition::metadata;

namespace {

nlohmann::json valid_body() {
  return nlohmann::json{
      {"verification_id", "11111111-1111-1111-1111-111111111111"},
  };
}

}  // namespace

TEST_CASE("parse_and_validate_create accepts a fully-populated body", "[metadata][validation]") {
  const auto request = parse_and_validate_create(valid_body());
  CHECK(request.verification_id == "11111111-1111-1111-1111-111111111111");
}

TEST_CASE("parse_and_validate_create rejects a missing verification_id", "[metadata][validation]") {
  auto body = valid_body();
  body.erase("verification_id");

  CHECK_THROWS_AS(parse_and_validate_create(body), ValidationError);
}

TEST_CASE("parse_and_validate_create reports its violation", "[metadata][validation]") {
  const nlohmann::json body = nlohmann::json::object();

  try {
    [[maybe_unused]] const auto ignored = parse_and_validate_create(body);
    FAIL("expected ValidationError");
  } catch (const ValidationError& error) {
    CHECK(error.violations().size() == 1);
  }
}

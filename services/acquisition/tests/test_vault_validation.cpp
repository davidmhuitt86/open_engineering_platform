#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/vault/validation.hpp"

using namespace oep::acquisition::vault;

namespace {

nlohmann::json valid_body() {
  return nlohmann::json{
      {"metadata_id", "11111111-1111-1111-1111-111111111111"},
  };
}

}  // namespace

TEST_CASE("parse_and_validate_publish accepts a fully-populated body", "[vault][validation]") {
  const auto request = parse_and_validate_publish(valid_body());
  CHECK(request.metadata_id == "11111111-1111-1111-1111-111111111111");
}

TEST_CASE("parse_and_validate_publish rejects a missing metadata_id", "[vault][validation]") {
  auto body = valid_body();
  body.erase("metadata_id");

  CHECK_THROWS_AS(parse_and_validate_publish(body), ValidationError);
}

TEST_CASE("parse_and_validate_publish reports its violation", "[vault][validation]") {
  const nlohmann::json body = nlohmann::json::object();

  try {
    [[maybe_unused]] const auto ignored = parse_and_validate_publish(body);
    FAIL("expected ValidationError");
  } catch (const ValidationError& error) {
    CHECK(error.violations().size() == 1);
  }
}

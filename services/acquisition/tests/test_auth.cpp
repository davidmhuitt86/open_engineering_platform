#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/api/auth.hpp"

using oep::acquisition::api::constant_time_equals;
using oep::acquisition::api::parse_bearer_token;

TEST_CASE("constant_time_equals matches equal strings", "[api][auth]") {
  CHECK(constant_time_equals("same-token", "same-token"));
  CHECK(constant_time_equals("", ""));
}

TEST_CASE("constant_time_equals rejects different strings", "[api][auth]") {
  CHECK_FALSE(constant_time_equals("token-a", "token-b"));
  CHECK_FALSE(constant_time_equals("short", "a-much-longer-value"));
  CHECK_FALSE(constant_time_equals("token", ""));
}

TEST_CASE("parse_bearer_token accepts a well-formed header", "[api][auth]") {
  const auto token = parse_bearer_token("Bearer abc123");
  REQUIRE(token.has_value());
  CHECK(*token == "abc123");
}

TEST_CASE("parse_bearer_token rejects a missing header value", "[api][auth]") {
  CHECK_FALSE(parse_bearer_token("").has_value());
}

TEST_CASE("parse_bearer_token rejects a different scheme", "[api][auth]") {
  CHECK_FALSE(parse_bearer_token("Basic abc123").has_value());
}

TEST_CASE("parse_bearer_token rejects the scheme with no token", "[api][auth]") {
  CHECK_FALSE(parse_bearer_token("Bearer ").has_value());
  CHECK_FALSE(parse_bearer_token("Bearer").has_value());
}

TEST_CASE("parse_bearer_token rejects a token containing whitespace", "[api][auth]") {
  CHECK_FALSE(parse_bearer_token("Bearer abc 123").has_value());
}

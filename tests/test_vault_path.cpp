#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/vault/vault_path.hpp"

using namespace oep::acquisition::vault;

TEST_CASE("compute_vault_path shards by the first two hex characters", "[vault][path]") {
  // "3f8b0d8e7c4e6" followed by enough trailing 'a' characters to reach
  // exactly 64 hex characters -- built programmatically rather than
  // hand-counted to avoid an off-by-one in the literal itself.
  const std::string prefix = "3f8b0d8e7c4e6";
  const std::string hash = prefix + std::string(64 - prefix.size(), 'a');
  REQUIRE(hash.size() == 64);

  const auto path = compute_vault_path("/reference_vault", hash);
  CHECK(path == std::filesystem::path("/reference_vault") / "3f" / hash);
}

TEST_CASE("compute_vault_path returns an empty path for a too-short hash", "[vault][path]") {
  const auto path = compute_vault_path("/reference_vault", "deadbeef");
  CHECK(path.empty());
}

TEST_CASE("compute_vault_path returns an empty path for a hash with non-hex characters", "[vault][path]") {
  const std::string not_hex(64, 'z');
  const auto path = compute_vault_path("/reference_vault", not_hex);
  CHECK(path.empty());
}

TEST_CASE("compute_vault_path returns an empty path for an uppercase hash", "[vault][path]") {
  // hash_file_sha256 always produces lowercase hex -- uppercase input is
  // treated as malformed rather than silently normalized.
  const std::string uppercase(64, 'A');
  const auto path = compute_vault_path("/reference_vault", uppercase);
  CHECK(path.empty());
}

TEST_CASE("compute_vault_path is deterministic for the same hash", "[vault][path]") {
  const std::string hash(64, 'a');
  const auto first = compute_vault_path("/reference_vault", hash);
  const auto second = compute_vault_path("/reference_vault", hash);
  CHECK(first == second);
}

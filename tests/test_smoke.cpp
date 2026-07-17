#include <catch2/catch_test_macros.hpp>

// WORK_PACKAGE_001 success criterion: "one passing smoke test," proving
// the Catch2 test project itself is wired up correctly, independent of
// any other module.
TEST_CASE("Catch2 test project is wired up", "[smoke]") {
  REQUIRE(1 + 1 == 2);
}

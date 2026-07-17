#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/downloads/download.hpp"

using namespace oep::acquisition::downloads;

TEST_CASE("clamp_progress_percentage computes an exact percentage", "[downloads][progress]") {
  CHECK(clamp_progress_percentage(0, 200) == 0);
  CHECK(clamp_progress_percentage(50, 200) == 25);
  CHECK(clamp_progress_percentage(100, 200) == 50);
  CHECK(clamp_progress_percentage(200, 200) == 100);
}

TEST_CASE("clamp_progress_percentage returns 0 when total_bytes is 0 (unknown total)",
          "[downloads][progress]") {
  CHECK(clamp_progress_percentage(0, 0) == 0);
  CHECK(clamp_progress_percentage(500, 0) == 0);
}

TEST_CASE("clamp_progress_percentage never exceeds 100 even if bytes_transferred > total_bytes",
          "[downloads][progress]") {
  // WORK_PACKAGE-006 Validation Rules: "Progress shall remain between 0
  // and 100" -- a connector misreporting more bytes transferred than the
  // total it declared must not produce an out-of-range percentage.
  CHECK(clamp_progress_percentage(300, 200) == 100);
}

TEST_CASE("clamp_progress_percentage never goes below 0", "[downloads][progress]") {
  CHECK(clamp_progress_percentage(1, 1000000) >= 0);
}

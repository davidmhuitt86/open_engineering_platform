#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/acquisition/acquisition_execution.hpp"

using namespace oep::acquisition::acquisition;

TEST_CASE("next_execution_status follows WORK_PACKAGE-004's forward execution edges",
          "[execution][transitions]") {
  CHECK(next_execution_status(JobStatus::Created) == JobStatus::Queued);
  CHECK(next_execution_status(JobStatus::Queued) == JobStatus::Running);
  CHECK(next_execution_status(JobStatus::Running) == JobStatus::Completed);
}

TEST_CASE("next_execution_status returns nullopt for terminal states", "[execution][transitions]") {
  CHECK_FALSE(next_execution_status(JobStatus::Completed).has_value());
  CHECK_FALSE(next_execution_status(JobStatus::Failed).has_value());
  CHECK_FALSE(next_execution_status(JobStatus::Cancelled).has_value());
}

TEST_CASE("can_cancel is true only for Queued and Running", "[execution][transitions]") {
  CHECK_FALSE(can_cancel(JobStatus::Created));
  CHECK(can_cancel(JobStatus::Queued));
  CHECK(can_cancel(JobStatus::Running));
  CHECK_FALSE(can_cancel(JobStatus::Completed));
  CHECK_FALSE(can_cancel(JobStatus::Failed));
  CHECK_FALSE(can_cancel(JobStatus::Cancelled));
}

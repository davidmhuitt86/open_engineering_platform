#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job.hpp"
#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"

namespace oep::acquisition::acquisition {

/// Validation + orchestration for the Engineering Acquisition Job Engine
/// (WORK_PACKAGE-003), mirroring `registry::OfficialSourceService`.
class AcquisitionJobService {
 public:
  explicit AcquisitionJobService(IAcquisitionJobRepository& repository);

  /// Throws ValidationError if `body` fails WORK_PACKAGE-003's validation
  /// rules; throws UnknownSourceError if `source_id` does not reference an
  /// existing Official Source.
  AcquisitionJob create(const nlohmann::json& body);

  std::optional<AcquisitionJob> get(const std::string& id);

  std::vector<AcquisitionJob> list(const JobFilter& filter);

  /// Empty optional if `id` does not exist. Throws ValidationError if
  /// `body` fails validation (including attempts to change immutable
  /// fields); throws UnknownSourceError if `source_id` does not reference
  /// an existing Official Source.
  std::optional<AcquisitionJob> update(const std::string& id, const nlohmann::json& body);

  bool remove(const std::string& id);

 private:
  IAcquisitionJobRepository& repository_;
};

}  // namespace oep::acquisition::acquisition

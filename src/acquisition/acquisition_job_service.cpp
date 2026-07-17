#include "oep/acquisition/acquisition/acquisition_job_service.hpp"

#include "oep/acquisition/acquisition/validation.hpp"

namespace oep::acquisition::acquisition {

AcquisitionJobService::AcquisitionJobService(IAcquisitionJobRepository& repository) : repository_(repository) {}

AcquisitionJob AcquisitionJobService::create(const nlohmann::json& body) {
  const AcquisitionJob job = parse_and_validate_create(body);
  return repository_.create(job);
}

std::optional<AcquisitionJob> AcquisitionJobService::get(const std::string& id) {
  return repository_.find_by_id(id);
}

std::vector<AcquisitionJob> AcquisitionJobService::list(const JobFilter& filter) {
  return repository_.list(filter);
}

std::optional<AcquisitionJob> AcquisitionJobService::update(const std::string& id, const nlohmann::json& body) {
  const auto existing = repository_.find_by_id(id);
  if (!existing.has_value()) {
    return std::nullopt;
  }
  const AcquisitionJob job = parse_and_validate_update(body, *existing);
  return repository_.update(id, job);
}

bool AcquisitionJobService::remove(const std::string& id) {
  return repository_.soft_delete(id);
}

}  // namespace oep::acquisition::acquisition

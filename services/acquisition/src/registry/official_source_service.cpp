#include "oep/acquisition/registry/official_source_service.hpp"

#include "oep/acquisition/registry/validation.hpp"

namespace oep::acquisition::registry {

OfficialSourceService::OfficialSourceService(IOfficialSourceRepository& repository) : repository_(repository) {}

OfficialSource OfficialSourceService::create(const nlohmann::json& body) {
  const OfficialSource source = parse_and_validate_create(body);
  return repository_.create(source);
}

std::optional<OfficialSource> OfficialSourceService::get(const std::string& id) {
  return repository_.find_by_id(id);
}

std::vector<OfficialSource> OfficialSourceService::list(const SourceFilter& filter) {
  return repository_.list(filter);
}

std::optional<OfficialSource> OfficialSourceService::update(const std::string& id, const nlohmann::json& body) {
  const auto existing = repository_.find_by_id(id);
  if (!existing.has_value()) {
    return std::nullopt;
  }
  const OfficialSource source = parse_and_validate_update(body, *existing);
  return repository_.update(id, source);
}

bool OfficialSourceService::remove(const std::string& id) {
  return repository_.soft_delete(id);
}

std::optional<OfficialSource> OfficialSourceService::set_status(const std::string& id, SourceStatus status) {
  const auto existing = repository_.find_by_id(id);
  if (!existing.has_value()) {
    return std::nullopt;
  }
  OfficialSource updated = *existing;
  updated.status = status;
  return repository_.update(id, updated);
}

std::optional<OfficialSource> OfficialSourceService::enable(const std::string& id) {
  return set_status(id, SourceStatus::Active);
}

std::optional<OfficialSource> OfficialSourceService::disable(const std::string& id) {
  return set_status(id, SourceStatus::Suspended);
}

}  // namespace oep::acquisition::registry

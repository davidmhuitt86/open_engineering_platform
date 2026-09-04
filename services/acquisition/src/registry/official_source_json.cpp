#include "oep/acquisition/registry/official_source_json.hpp"

namespace oep::acquisition::registry {

nlohmann::json to_json(const OfficialSource& source) {
  return nlohmann::json{
      {"id", source.id},
      {"name", source.name},
      {"organization", source.organization},
      {"base_url", source.base_url},
      {"description", source.description},
      {"country", source.country},
      {"language", source.language},
      {"category", source.category},
      {"trust_level", static_cast<int>(source.trust_level)},
      {"status", to_string(source.status)},
      {"authentication_type", to_string(source.authentication_type)},
      {"created_at", source.created_at},
      {"updated_at", source.updated_at},
  };
}

}  // namespace oep::acquisition::registry

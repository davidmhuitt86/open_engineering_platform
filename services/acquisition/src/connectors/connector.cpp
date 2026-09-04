#include "oep/acquisition/connectors/connector.hpp"

namespace oep::acquisition::connectors {

std::string to_string(HealthStatus status) {
  switch (status) {
    case HealthStatus::Healthy:
      return "healthy";
    case HealthStatus::Unhealthy:
      return "unhealthy";
    case HealthStatus::Unknown:
      return "unknown";
  }
  return "unknown";
}

}  // namespace oep::acquisition::connectors

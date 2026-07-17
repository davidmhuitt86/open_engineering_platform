#include "oep/acquisition/common/time.hpp"

#include <chrono>
#include <ctime>

namespace oep::acquisition::common {

std::string current_timestamp_utc() {
  const std::time_t now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  std::tm utc_tm{};
#ifdef _WIN32
  gmtime_s(&utc_tm, &now);
#else
  gmtime_r(&now, &utc_tm);
#endif
  char buffer[32];
  std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc_tm);
  return buffer;
}

}  // namespace oep::acquisition::common

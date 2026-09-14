#pragma once

#include <memory>

#include <spdlog/logger.h>

#include "oep/server_repository/common/config.hpp"

namespace oep::server_repository::common {

/// Process-wide logging initialization. Mirrors
/// services/acquisition's own Logger exactly.
class Logger {
 public:
  static void initialize(const LoggingConfig& config);
  static spdlog::logger& get();

 private:
  static std::shared_ptr<spdlog::logger> instance_;
};

}  // namespace oep::server_repository::common

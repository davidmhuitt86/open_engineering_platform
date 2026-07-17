#pragma once

#include <memory>
#include <string>

#include <spdlog/logger.h>

#include "oep/acquisition/common/config.hpp"

namespace oep::acquisition::common {

/// Process-wide logging initialization (WORK_PACKAGE_001).
///
/// Wraps spdlog rather than exposing it directly so call sites depend on
/// one small OEP-owned surface (`Logger::get()`, `LOG_INFO(...)`-style
/// convenience is intentionally not introduced here -- callers use the
/// returned `spdlog::logger&` directly, matching spdlog's own idiom).
class Logger {
 public:
  /// Initializes the global logger from `config` -- level, and console
  /// and/or file sinks. Safe to call more than once (each call replaces
  /// the previous logger); tests do this routinely.
  static void initialize(const LoggingConfig& config);

  /// Returns the process-wide logger. Initializes it with defaults
  /// (info level, console only) on first use if `initialize` was never
  /// called, so any component can log without a strict startup-ordering
  /// requirement.
  static spdlog::logger& get();

 private:
  static std::shared_ptr<spdlog::logger> instance_;
};

}  // namespace oep::acquisition::common

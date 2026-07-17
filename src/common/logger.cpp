#include "oep/acquisition/common/logger.hpp"

#include <vector>

#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

namespace oep::acquisition::common {

namespace {

spdlog::level::level_enum parse_level(const std::string& level) {
  const auto parsed = spdlog::level::from_str(level);
  // spdlog::level::from_str silently returns `off` for an unrecognized
  // string, which would otherwise swallow every log line without any
  // indication why -- fall back to `info` instead so a typo'd config
  // value degrades to "too chatty," not "silently mute."
  if (parsed == spdlog::level::off && level != "off") {
    return spdlog::level::info;
  }
  return parsed;
}

}  // namespace

std::shared_ptr<spdlog::logger> Logger::instance_ = nullptr;

void Logger::initialize(const LoggingConfig& config) {
  std::vector<spdlog::sink_ptr> sinks;

  if (config.console) {
    sinks.push_back(std::make_shared<spdlog::sinks::stdout_color_sink_mt>());
  }
  if (!config.file.empty()) {
    sinks.push_back(std::make_shared<spdlog::sinks::basic_file_sink_mt>(config.file, /*truncate=*/false));
  }
  if (sinks.empty()) {
    // Never construct a logger with zero sinks -- that would silently
    // discard every log line with no diagnostic at all.
    sinks.push_back(std::make_shared<spdlog::sinks::stdout_color_sink_mt>());
  }

  auto logger = std::make_shared<spdlog::logger>("oep_acquisition", sinks.begin(), sinks.end());
  logger->set_level(parse_level(config.level));
  logger->flush_on(spdlog::level::warn);

  instance_ = logger;
  spdlog::set_default_logger(logger);
}

spdlog::logger& Logger::get() {
  if (instance_ == nullptr) {
    initialize(LoggingConfig{});
  }
  return *instance_;
}

}  // namespace oep::acquisition::common

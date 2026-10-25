// ============================================================================
//  logging.cc — easylog logger configuration from LogConfig.
// ============================================================================
#include "rtos_manager/logging.hpp"

#include <cctype>
#include <filesystem>
#include <string>
#include <ylt/easylog.hpp>

namespace rtos_manager {
namespace {

/// Map a case-insensitive level name to an easylog Severity. Unknown values
/// fall back to INFO.
auto ToSeverity(std::string_view level) -> easylog::Severity {
  auto s = std::string{};
  s.reserve(level.size());
  for (const auto& c : level) {
    s.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
  }
  if (s == "trace") {
    return easylog::Severity::TRACE;
  }
  if (s == "debug") {
    return easylog::Severity::DEBUG;
  }
  if (s == "warn" || s == "warning") {
    return easylog::Severity::WARN;
  }
  if (s == "error") {
    return easylog::Severity::ERROR;
  }
  if (s == "critical" || s == "fatal") {
    return easylog::Severity::CRITICAL;
  }
  if (s == "off" || s == "none") {
    return easylog::Severity::NONE;
  }
  return easylog::Severity::INFO;
}

}  // namespace

auto InitLogging(const LogConfig& cfg) -> void {
  const auto file = std::string{cfg.file};
  if (!file.empty()) {
    if (const std::filesystem::path log_path(file); log_path.has_parent_path()) {
      std::filesystem::create_directories(log_path.parent_path());
    }
  }

  // async=false keeps output deterministic (a short-lived CLI process must not
  // lose buffered records on exit) and needs no explicit shutdown flush.
  easylog::init_log<0>(ToSeverity(cfg.level), file, /*async=*/false,
                       /*enable_console=*/cfg.console, cfg.max_size, cfg.max_files, /*flush_every_time=*/false);
}

}  // namespace rtos_manager

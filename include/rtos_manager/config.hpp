// ============================================================================
//  rtos_manager/config.hpp — application configuration (YAML via Glaze)
//
//  The structs below are plain aggregates, so Glaze's compile-time reflection
//  maps YAML keys <-> members automatically (no macros / no glz::meta needed).
//  Keep the YAML keys in config/rtos_manager.yaml in sync with member names.
// ============================================================================
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace rtos_manager {

/// HTTP server settings.
struct ServerConfig {
  std::string host{"0.0.0.0"};
  std::uint16_t port{8080};
  std::size_t io_threads{1};
};

/// Logging settings (consumed by easylog in logging.cc).
struct LogConfig {
  std::string level{"info"};                ///< trace|debug|info|warning|error|critical
  std::string file{"logs/rtos-manager.log"}; ///< empty disables the file sink
  std::uint64_t max_size{10485760};         ///< rotate once the file exceeds N bytes
  std::size_t max_files{5};                 ///< keep at most N rotated files
  bool console{true};                       ///< also echo to stdout
};

/// Top-level configuration object.
struct AppConfig {
  ServerConfig server{};
  LogConfig logging{};
};

/// Load and parse a YAML configuration file into AppConfig.
/// Missing keys keep the defaults declared above.
/// @throws std::runtime_error when the file cannot be opened or parsed.
AppConfig LoadConfig(const std::string& path);

}  // namespace rtos_manager

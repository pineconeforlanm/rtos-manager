// ============================================================================
//  rtos_manager/version.hpp — public build/version metadata API
//
//  The concrete values are generated at configure time into
//  <build>/generated/rtos_manager/version_info.hpp (see cmake/version_info.cmake)
//  and baked into the binary.
// ============================================================================
#pragma once

#include <string>

namespace rtos_manager {

/// Compact single-line version, e.g. "0.1.0 (a1b2c3d on develop)"
std::string VersionString();

/// Emits the full multi-line build report (project, git, build, system,
/// compiler) through the logging framework (easylog). Each section is one log
/// line, so it carries the configured log pattern and reaches every sink.
void LogVersion();

}  // namespace rtos_manager

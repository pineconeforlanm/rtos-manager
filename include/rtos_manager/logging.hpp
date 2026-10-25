// ============================================================================
//  rtos_manager/logging.hpp — easylog-based logging bootstrap.
// ============================================================================
#pragma once

#include "rtos_manager/config.hpp"

namespace rtos_manager {

/// Configure the process-wide easylog logger from the `logging` section of the
/// configuration: severity, optional rotating log file and console output.
/// Passing an empty `cfg.file` yields a console-only logger.
auto InitLogging(const LogConfig& cfg) -> void;

}  // namespace rtos_manager

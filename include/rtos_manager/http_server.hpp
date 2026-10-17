// ============================================================================
//  rtos_manager/http_server.hpp — coro_http (yalantinglibs) HTTP backend.
// ============================================================================
#pragma once

#include "rtos_manager/config.hpp"

namespace rtos_manager {

/// Start the HTTP server (blocks until shutdown). Registers the RESTful
/// endpoints: GET /, GET /hello and GET /api/v1/version.
void RunHttpServer(const ServerConfig& cfg);

}  // namespace rtos_manager

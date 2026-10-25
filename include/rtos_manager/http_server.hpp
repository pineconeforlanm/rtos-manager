// ============================================================================
//  rtos_manager/http_server.hpp — coro_http (yalantinglibs) HTTP backend.
// ============================================================================
#pragma once

#include "rtos_manager/config.hpp"

// Only references to these types appear below, so the heavy header-only
// coro_http headers stay out of this file and out of everything that includes it.
namespace cinatra {
class coro_http_request;
class coro_http_response;
}  // namespace cinatra

namespace rtos_manager {

/// Payload of GET /api/v1/version: status 200, the JSON build document, and its
/// content type. Kept apart from the route registration so the handler can be
/// driven with a plain coro_http_response — no socket, no event loop.
auto HandleVersionRequest(cinatra::coro_http_request& req, cinatra::coro_http_response& res) -> void;

/// Start the HTTP server (blocks until shutdown). Registers the RESTful
/// endpoint GET /api/v1/version.
auto RunHttpServer(const ServerConfig& cfg) -> void;

}  // namespace rtos_manager

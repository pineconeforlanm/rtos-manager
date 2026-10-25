// ============================================================================
//  http_server.cc — coro_http (yalantinglibs) HTTP backend.
//
//  coro_http is header-only and consumed via the rtos::ylt target; its public
//  types live in namespace cinatra. Handlers here are plain (non-coroutine)
//  callables that fill the response synchronously.
//
//  MVP surface: a single endpoint, GET /api/v1/version, served straight from
//  BuildInfo::ToJson() — the handler owns no rendering logic of its own.
// ============================================================================
#include "rtos_manager/http_server.hpp"

#include <tuple>
#include <ylt/coro_http/coro_http_server.hpp>
#include <ylt/easylog.hpp>

#include "rtos_manager/version.hpp"

namespace rtos_manager {

auto HandleVersionRequest(cinatra::coro_http_request& /*req*/, cinatra::coro_http_response& res) -> void {
  res.set_status_and_content(cinatra::status_type::ok, BuildInfo::Get().ToJson());
  res.add_header("Content-Type", "application/json");
}

auto RunHttpServer(const ServerConfig& cfg) -> void {
  auto server = cinatra::coro_http_server(cfg.io_threads, cfg.port);

  // RESTful version resource (JSON) — the only endpoint in the MVP.
  server.set_http_handler<cinatra::GET>(
      "/api/v1/version",
      [](cinatra::coro_http_request& req, cinatra::coro_http_response& res) { HandleVersionRequest(req, res); });

  ELOGFMT(INFO, "starting coro_http server on {}:{} (io_threads={})", cfg.host, cfg.port, cfg.io_threads);
  std::ignore = server.sync_start();  // blocks until stopped / process ends
  ELOGFMT(INFO, "coro_http server stopped");
}

}  // namespace rtos_manager

// ============================================================================
//  http_server.cc — coro_http (yalantinglibs) HTTP backend.
//
//  coro_http is header-only and consumed via the rtos::ylt target; its public
//  types live in namespace cinatra. Handlers here are plain (non-coroutine)
//  callables that fill the response synchronously.
//
//  MVP surface: a single endpoint, GET /api/v1/version, returning the
//  compile-time build metadata as JSON.
// ============================================================================
#include "rtos_manager/http_server.hpp"

#include <format>
#include <string>

#include <ylt/coro_http/coro_http_server.hpp>
#include <ylt/easylog.hpp>

#include "rtos_manager/version_info.hpp"  // AUTO-GENERATED

namespace rtos_manager {
namespace {

/// Build the JSON document served by GET /api/v1/version.
std::string VersionJson() {
  return std::format(
      R"({{"project":"{}","version":"{}","gitHash":"{}","branch":"{}","tag":"{}","describe":"{}","dirty":{},"prerelease":{},"buildType":"{}","buildTime":"{}","system":"{}","processor":"{}","compiler":"{} {}","cxxStandard":"{}"}})",
      build::kProjectName, build::kVersionSemver, build::kGitHash,
      build::kGitBranch, build::kGitTag, build::kGitDescribe, build::kGitDirty,
      build::kVersionIsPrerelease, build::kBuildType, build::kBuildTime,
      build::kSystemName, build::kSystemProcessor, build::kCompilerId,
      build::kCompilerVersion, build::kCxxStandard);
}

}  // namespace

void RunHttpServer(const ServerConfig& cfg) {
  cinatra::coro_http_server server(cfg.io_threads, cfg.port);

  // RESTful version resource (JSON) — the only endpoint in the MVP.
  server.set_http_handler<cinatra::GET>(
      "/api/v1/version",
      [](cinatra::coro_http_request&, cinatra::coro_http_response& res) {
        res.set_status_and_content(cinatra::status_type::ok, VersionJson());
        res.add_header("Content-Type", "application/json");
      });

  ELOGFMT(INFO, "starting coro_http server on {}:{} (io_threads={})", cfg.host,
          cfg.port, cfg.io_threads);
  std::ignore = server.sync_start();  // blocks until stopped / process ends
  ELOGFMT(INFO, "coro_http server stopped");
}

}  // namespace rtos_manager

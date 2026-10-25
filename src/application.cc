// ============================================================================
//  application.cc — startup pipeline of the rtos-manager process.
// ============================================================================
#include "rtos_manager/application.hpp"

#include <exception>
#include <print>
#include <utility>
#include <ylt/easylog.hpp>

#include "rtos_manager/http_server.hpp"
#include "rtos_manager/logging.hpp"
#include "rtos_manager/version.hpp"

namespace rtos_manager {

Application::Application(CommandLine request) noexcept : request_(std::move(request)) {}

auto Application::Run(int argc, const char* const* argv, const ServerRunner& runner) -> int {
  auto app = Application{CommandLine::Parse(argc, argv)};

  // Stage 1: a request that needs no configuration short-circuits before any
  // file is read and before a logger exists, so `-v` can never fail because of
  // a broken YAML file — nor leave a log file behind.
  if (const auto version = app.request_.RequestedVersion(); version != VersionRequest::kNone) {
    app.ShowVersion(version);
    return 0;
  }

  InitProvisionalLogging();

  if (!app.LoadConfiguration()) {
    return 1;
  }
  return app.Serve(runner);
}

auto Application::InitProvisionalLogging() -> void {
  auto provisional = LogConfig{};
  provisional.file.clear();  // CLI actions must not create a log file
  InitLogging(provisional);
}

auto Application::ShowVersion(const VersionRequest request) const -> void {
  // Straight to stdout, not through easylog: these flags answer a question and
  // exit, and `[timestamp] INFO [pid] [file:line]` in front of every field made
  // the output awkward to grep and impossible to diff between two builds.
  const auto& info = BuildInfo::Get();
  if (request == VersionRequest::kFull) {
    std::print("{}", info.ToReport());
    return;
  }
  std::print("{} {}\n", info.ProjectName(), info.ToString());
}

auto Application::LoadConfiguration() -> bool {
  if (!request_.HasConfig()) {
    return true;  // built-in defaults are a valid configuration
  }
  try {
    config_ = LoadConfig(request_.ConfigPath());
  } catch (const std::exception& e) {
    ELOGFMT(ERROR, "failed to load configuration: {}", e.what());
    return false;
  }
  return true;
}

auto Application::Serve(const ServerRunner& runner) -> int {
  // The real logger replaces the provisional one now that its settings exist.
  InitLogging(config_.logging);

  ELOGFMT(INFO, "rtos-manager {} starting", BuildInfo::Get().ToString());
  try {
    runner(config_.server);
  } catch (const std::exception& e) {
    ELOGFMT(ERROR, "server error: {}", e.what());
    return 1;
  }
  return 0;
}

}  // namespace rtos_manager
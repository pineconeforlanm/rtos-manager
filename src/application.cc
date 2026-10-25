// ============================================================================
//  application.cc — startup pipeline of the rtos-manager process.
// ============================================================================
#include "rtos_manager/application.hpp"

#include <exception>
#include <utility>
#include <ylt/easylog.hpp>

#include "rtos_manager/http_server.hpp"
#include "rtos_manager/logging.hpp"
#include "rtos_manager/version.hpp"

namespace rtos_manager {

Application::Application(CommandLine request) noexcept : request_(std::move(request)) {}

auto Application::Run(int argc, const char* const* argv, const ServerRunner& runner) -> int {
  auto app = Application{CommandLine::Parse(argc, argv)};

  InitProvisionalLogging();

  // Stage 1: a request that needs no configuration short-circuits before any
  // file is touched, so `-v` can never fail because of a broken YAML file.
  if (app.request_.WantsVersion()) {
    app.ShowVersion();
    return 0;
  }

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

auto Application::ShowVersion() const -> void {
  const auto& info = BuildInfo::Get();
  ELOGFMT(INFO, "{} {}", info.ProjectName(), info.Semver());
  ELOGFMT(INFO, "  description : {}", info.ProjectDescription());
  ELOGFMT(INFO, "  homepage    : {}", info.ProjectHomepage());
  ELOGFMT(INFO, "  git         : {} [hash={} branch={} tag={} commits={} dirty={} date={}]", info.GitDescribe(),
          info.GitHash(), info.GitBranch(), info.GitTag(), info.CommitCount(), info.IsDirty(), info.CommitDate());
  ELOGFMT(INFO, "  build       : type={} time={} UTC", info.BuildType(), info.BuildTimestamp());
  ELOGFMT(INFO, "  system      : {} {} ({})", info.SystemName(), info.SystemVersion(), info.Processor());
  ELOGFMT(INFO, "  compiler    : {} {} (C++{})", info.CompilerId(), info.CompilerVersion(), info.CxxStandard());
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
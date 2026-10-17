// ============================================================================
//  main.cc — rtos-manager entry point: a CLI tool AND an HTTP service.
//
//  Supported flags (and nothing else):
//    -h, --help      print usage and exit (handled by CLI11)
//    -v, --version   print build metadata baked into the binary and exit
//    -c, --config    path to the YAML configuration file
//
//  With no -v flag the process starts the coro_http HTTP server (daemon mode,
//  managed by systemd). Every runtime knob (listen host/port, threads, logging)
//  lives in the YAML file — there are no per-option CLI overrides by design.
// ============================================================================
#include <CLI/CLI.hpp>
#include <ylt/easylog.hpp>

#include <exception>
#include <string>

#include "rtos_manager/config.hpp"
#include "rtos_manager/http_server.hpp"
#include "rtos_manager/logging.hpp"
#include "rtos_manager/version.hpp"

int main(int argc, char** argv) {
  CLI::App app{"rtos-manager — RTOS device management HTTP service (and CLI tool)"};
  app.set_help_flag("-h,--help", "Print this help message and exit");

  std::string config_path;
  bool show_version{false};

  app.add_option("-c,--config", config_path, "Path to YAML configuration file")
      ->check(CLI::ExistingFile);
  app.add_flag("-v,--version", show_version, "Print build & version information and exit");

  CLI11_PARSE(app, argc, argv);

  // Provisional console-only logger so early messages (including --version and
  // config errors) flow through the logging framework. Reconfigured below with
  // the sinks/level coming from the loaded YAML once it is available.
  {
    rtos_manager::LogConfig provisional;
    provisional.file.clear();  // console only; CLI actions must not create a log file
    rtos_manager::InitLogging(provisional);
  }

  if (show_version) {
    rtos_manager::LogVersion();
    return 0;
  }

  // Configuration: built-in defaults, optionally overlaid by the YAML file.
  rtos_manager::AppConfig cfg{};
  if (!config_path.empty()) {
    try {
      cfg = rtos_manager::LoadConfig(config_path);
    } catch (const std::exception& e) {
      ELOGFMT(ERROR, "failed to load configuration: {}", e.what());
      return 1;
    }
  }

  // Apply the configured logging (level, file rotation, console toggle).
  rtos_manager::InitLogging(cfg.logging);

  ELOGFMT(INFO, "rtos-manager {} starting", rtos_manager::VersionString());
  try {
    rtos_manager::RunHttpServer(cfg.server);
  } catch (const std::exception& e) {
    ELOGFMT(ERROR, "server error: {}", e.what());
    return 1;
  }
  return 0;
}

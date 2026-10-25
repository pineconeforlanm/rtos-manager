// ============================================================================
//  rtos_manager/application.hpp — process lifecycle orchestrator
//
//  Layering, top to bottom:
//    main()          process entry point (one call)
//    Application     lifecycle: which stage runs, in which order, this file
//    CommandLine     argv -> request      (cli.hpp)
//    AppConfig       YAML -> settings     (config.hpp)
//    RunHttpServer   settings -> sockets   (http_server.hpp)
//  Each layer only knows the one below it, so the startup order is readable in
//  a single place instead of being spread across procedural top-level code.
// ============================================================================
#pragma once

#include <functional>

#include "rtos_manager/cli.hpp"
#include "rtos_manager/config.hpp"
#include "rtos_manager/http_server.hpp"

namespace rtos_manager {

/// Turns a parsed command line into either a running service or an exit status.
///
/// Deliberately not a namespace of free functions: the stages share the same
/// state (the request, then the configuration it produced), and keeping that
/// state as members makes the data flow explicit instead of threading arguments
/// through helpers.
class Application {
 public:
  /// How the service is brought up. The default is the real backend; the
  /// parameter is the single seam that lets a test observe the whole lifecycle
  /// (version, configuration, serving, error mapping) without binding a socket.
  using ServerRunner = std::function<void(const ServerConfig&)>;

  /// Run the requested action and return the process exit status.
  /// Never throws: failures are reported through the logger and mapped to a
  /// non-zero status.
  /// `argv` is a read-only view (`const char* const*`) — see CommandLine::Parse.
  [[nodiscard]] static auto Run(int argc, const char* const* argv, const ServerRunner& runner = RunHttpServer) -> int;

 private:
  /// Only meaningful with a request in hand, so construction is not public.
  explicit Application(CommandLine request) noexcept;

  /// Stage 1 (`-v` / `--version`): print the requested version report to
  /// stdout and exit. Not routed through the logger on purpose — the flag is a
  /// query, so the text must stay free of log prefixes.
  /// @param request which report to print; kNone never reaches this call.
  auto ShowVersion(VersionRequest request) const -> void;
  /// Stage 2: a console-only logger, so the stages below — including
  /// configuration errors — can report through the logging framework.
  static auto InitProvisionalLogging() -> void;
  /// Stage 3: overlay the YAML file onto the built-in defaults.
  /// @return false when a file was given but could not be used.
  [[nodiscard]] auto LoadConfiguration() -> bool;
  /// Stage 4: bring up the configured logger, then serve until shutdown.
  /// @param runner the backend to start; see ServerRunner.
  [[nodiscard]] auto Serve(const ServerRunner& runner) -> int;

  CommandLine request_;
  AppConfig config_{};
};

}  // namespace rtos_manager
// ============================================================================
//  main.cc — process entry point.
//
//  Everything the program does lives one layer down, so this file only has to
//  satisfy the C runtime contract:
//    Application::Run()  startup pipeline (application.hpp)
//    CommandLine         argument parsing   (cli.hpp)
//    AppConfig           YAML settings      (config.hpp)
//    RunHttpServer       HTTP service       (http_server.hpp)
//  Supported flags: -h/--help, -v (one version line), --version (full build
//  report), -c/--config <file>. Every runtime knob (listen host/port, threads,
//  logging) lives in the YAML file — there are no per-option CLI overrides by
//  design.
// ============================================================================
#include <cstdlib>
#include <exception>
#include <print>

#include "rtos_manager/application.hpp"

namespace {

/// Read-only view of the arguments: `const char**` is *not* a legal conversion
/// target for `char**` (only `const char* const*` is), so the const-ness stops
/// at one level of indirection.
auto RealMain(const int argc, const char* const* argv) -> int { return rtos_manager::Application::Run(argc, argv); }

/// Last-resort barrier: no exception may cross the process boundary.
auto ImplMain(const int argc, const char* const* argv) -> int {
  try {
    return RealMain(argc, argv);
  } catch (const std::exception& exp) {
    std::println("Main Exception: {}", exp.what());
    return EXIT_FAILURE;
  }
}

}  // namespace

// The entry point itself keeps the standard-mandated `char* argv[]`; the
// read-only view starts one frame further in.
auto main(const int argc, char** argv) -> int { return ImplMain(argc, argv); }

// ============================================================================
//  cli.cc — CLI11-backed implementation of CommandLine.
// ============================================================================
#include "rtos_manager/cli.hpp"

#include <CLI/CLI.hpp>
#include <cstdlib>

namespace rtos_manager {

auto CommandLine::Parse(int argc, const char* const* argv) -> CommandLine {
  auto app = CLI::App{"rtos-manager — RTOS device management HTTP service (and CLI tool)"};
  app.set_help_flag("-h,--help", "Print this help message and exit");

  // Bind straight into the result object: whatever the parser writes is what we
  // hand back, so there is no intermediate state to keep in sync.
  auto options = CommandLine{};
  app.add_option("-c,--config", options.config_path_, "Path to YAML configuration file")->check(CLI::ExistingFile);
  app.add_flag("-v,--version", options.wants_version_, "Print build & version information and exit");

  try {
    app.parse(argc, argv);
  } catch (const CLI::ParseError& e) {
    // `exit()` renders the help or the error message itself and returns the
    // status CLI11 considers conventional; the process is already on its way
    // out, so terminate rather than unwind into a half-initialised runtime.
    std::exit(app.exit(e));
  }
  return options;
}

auto CommandLine::ConfigPath() const noexcept -> const std::string& { return config_path_; }

auto CommandLine::HasConfig() const noexcept -> bool { return !config_path_.empty(); }

auto CommandLine::WantsVersion() const noexcept -> bool { return wants_version_; }

}  // namespace rtos_manager
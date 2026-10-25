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
  // Two flags, not one with two names: -v and --version answer different
  // questions (see VersionRequest). Binding them separately is what makes the
  // distinction visible here instead of being guessed from the matched name.
  app.add_flag("-v", options.wants_brief_version_, "Print the version line and exit");
  app.add_flag("--version", options.wants_full_version_, "Print the full build information and exit");

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

auto CommandLine::RequestedVersion() const noexcept -> VersionRequest {
  // --version is the superset, so it wins if both flags were given.
  if (wants_full_version_) {
    return VersionRequest::kFull;
  }
  return wants_brief_version_ ? VersionRequest::kBrief : VersionRequest::kNone;
}

}  // namespace rtos_manager
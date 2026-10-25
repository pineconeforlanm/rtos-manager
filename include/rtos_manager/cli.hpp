// ============================================================================
//  rtos_manager/cli.hpp — command-line parsing layer
//
//  argv is turned into a small value object here and nothing else. Parsing is a
//  self-contained concern: it does not read files, start services or configure
//  logging — it only answers *what was asked for*. Application (application.hpp)
//  acts on those answers.
// ============================================================================
#pragma once

#include <string>

namespace rtos_manager {

/// Which version report the command line asked for.
///
/// The two flags are deliberately distinct rather than one alias of the other:
/// `-v` answers "which build am I running?" in a single line (scripts, `dpkg`
/// post-install checks), while `--version` is the full report a bug report
/// needs. Printing happens in Application; this only records the request.
enum class VersionRequest {
  kNone,   ///< No version flag given.
  kBrief,  ///< `-v`: one line, e.g. "rtos_manager 0.1.2-rc.1 (c2a0dff on main)".
  kFull,   ///< `--version`: every field of the build metadata, one per line.
};

/// The request expressed on the command line, as data.
///
/// Result of parsing, not a parser: the CLI11::App lives and dies inside
/// Parse(), so this object is copyable, inspectable and free of parser state.
/// Callers that merely consume options therefore never see CLI11 — the
/// dependency stays private to cli.cc.
class CommandLine {
 public:
  /// Parse argv (element 0 is the program name).
  /// @note The parameter is `const char* const*`, not `const char**`: only the
  ///       former is a valid conversion target for the `char**` a C runtime
  ///       entry point hands out.
  /// @note Help and malformed input are terminal: CLI11 prints its own
  ///       help/error text and the process exits with the conventional status.
  ///       That is deliberate — argv is parsed exactly once, by the process
  ///       entry point, so no caller above this layer could handle the failure.
  [[nodiscard]] static auto Parse(int argc, const char* const* argv) -> CommandLine;

  /// Value of -c/--config; empty when the flag was absent.
  [[nodiscard]] auto ConfigPath() const noexcept -> const std::string&;
  /// True when a configuration file was requested.
  [[nodiscard]] auto HasConfig() const noexcept -> bool;
  /// Which version report -v/--version asked for; kNone when neither was given.
  /// `--version` wins when both flags appear, since it is a superset.
  [[nodiscard]] auto RequestedVersion() const noexcept -> VersionRequest;

 private:
  CommandLine() noexcept = default;

  std::string config_path_{};
  bool wants_brief_version_{false};
  bool wants_full_version_{false};
};

}  // namespace rtos_manager
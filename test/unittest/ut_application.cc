// ============================================================================
//  ut_application.cc — unit tests for the Application lifecycle
//
//  Run() is exercised end to end (argv -> version | configuration -> serve) with
//  the backend injected as a stub, so the whole startup pipeline is covered
//  without binding a socket or blocking. The stub doubles as an observation
//  point: it proves *which* configuration reached the server layer.
// ============================================================================
#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <initializer_list>
#include <optional>
#include <random>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "rtos_manager/application.hpp"
#include "rtos_manager/config.hpp"

namespace {

using rtos_manager::Application;
using rtos_manager::ServerConfig;

/// Unique temporary path; `suffix` keeps .yaml files recognisable.
auto TempPath(std::string_view suffix) -> std::filesystem::path {
  std::random_device rd;
  return std::filesystem::temp_directory_path() /
         ("rtos-manager-app-test-" + std::to_string(rd()) + std::string{suffix});
}

auto WriteTempFile(std::string_view content, std::string_view suffix = ".yaml") -> std::string {
  const auto path = TempPath(suffix);
  std::ofstream out(path);
  out << content;
  return path.string();
}

/// Run the process pipeline behind a synthetic argv[0] ("rtos-manager").
/// (Named RunApp because GoogleTest's Test base class already declares Run.)
auto RunApp(std::initializer_list<std::string_view> args, const Application::ServerRunner& runner) -> int {
  auto storage = std::vector<std::string>{"rtos-manager"};
  storage.reserve(args.size() + 1);
  for (const auto arg : args) {
    storage.emplace_back(arg);
  }

  // CLI11 wants a mutable `char**`; `storage` outlives the call.
  auto argv = std::vector<char*>{};
  argv.reserve(storage.size());
  for (auto& arg : storage) {
    argv.push_back(arg.data());
  }
  return Application::Run(static_cast<int>(argv.size()), argv.data(), runner);
}

/// A backend that only records that it was asked to start.
struct RecordingBackend {
  bool called{false};
  std::optional<ServerConfig> seen{};
};

TEST(ApplicationTest, VersionFlagNeverTouchesTheConfiguration) {
  // The YAML file is deliberately unparsable: -v must short-circuit before
  // LoadConfiguration(), so the process still succeeds.
  const auto broken = WriteTempFile("server: [unterminated\n");
  RecordingBackend backend;

  EXPECT_EQ(RunApp({"-v", "-c", broken},
                   [&backend](const ServerConfig& cfg) {
                     backend.called = true;
                     backend.seen = cfg;
                   }),
            0);
  EXPECT_FALSE(backend.called);
}

TEST(ApplicationTest, UnparsableConfigurationFailsWithoutServing) {
  const auto broken = WriteTempFile("server: [unterminated\n");
  RecordingBackend backend;

  EXPECT_EQ(RunApp({"-c", broken}, [&backend](const ServerConfig&) { backend.called = true; }), 1);
  EXPECT_FALSE(backend.called);
}

TEST(ApplicationTest, ServeReceivesTheLoadedConfiguration) {
  const auto log_file = TempPath(".log");
  std::filesystem::remove_all(log_file);  // the nested parent must be created by InitLogging

  const auto config = WriteTempFile(
      "server:\n"
      "  host: 127.0.0.1\n"
      "  port: 18080\n"
      "  io_threads: 2\n"
      "logging:\n"
      "  level: debug\n"
      "  file: " +
      log_file.string() + "\n  console: false\n");
  RecordingBackend backend;

  EXPECT_EQ(RunApp({"-c", config},
                   [&backend](const ServerConfig& cfg) {
                     backend.called = true;
                     backend.seen = cfg;
                   }),
            0);

  ASSERT_TRUE(backend.called);
  ASSERT_TRUE(backend.seen.has_value());
  EXPECT_EQ(backend.seen->host, "127.0.0.1");
  EXPECT_EQ(backend.seen->port, 18080);
  EXPECT_EQ(backend.seen->io_threads, 2u);

  // InitLogging() creates the parent directory of the configured log file.
  EXPECT_TRUE(std::filesystem::exists(log_file.parent_path()));
  std::filesystem::remove_all(log_file);
}

TEST(ApplicationTest, BackendFailureBecomesNonZeroExit) {
  // A console-only, file-less configuration keeps the test hermetic.
  const auto config = WriteTempFile("logging:\n  file: \"\"\n  console: false\n");

  EXPECT_EQ(RunApp({"-c", config}, [](const ServerConfig&) { throw std::runtime_error("bind failed"); }), 1);
}

}  // namespace

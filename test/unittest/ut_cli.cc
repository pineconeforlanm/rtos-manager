// ============================================================================
//  ut_cli.cc — unit tests for rtos_manager::CommandLine
//
//  Parse() is a pure factory over argv, so every case just builds an argument
//  vector. Invalid input and --help are terminal by design (see cli.hpp): they
//  exit the process, so they have no in-process test.
//  Test names follow the GoogleTest CamelCase convention used across the suite.
// ============================================================================
#include <gtest/gtest.h>

#include <initializer_list>
#include <string>
#include <string_view>
#include <vector>

#include "rtos_manager/cli.hpp"

namespace {

using rtos_manager::CommandLine;

/// Parse the given arguments behind a synthetic argv[0] ("rtos-manager").
auto Parse(std::initializer_list<std::string_view> args) -> CommandLine {
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
  return CommandLine::Parse(static_cast<int>(argv.size()), argv.data());
}

TEST(CommandLineTest, DefaultsToNoRequest) {
  const auto cmd = Parse({});
  EXPECT_FALSE(cmd.HasConfig());
  EXPECT_FALSE(cmd.WantsVersion());
  EXPECT_TRUE(cmd.ConfigPath().empty());
}

TEST(CommandLineTest, VersionFlagIsDetected) {
  EXPECT_TRUE(Parse({"-v"}).WantsVersion());
  EXPECT_TRUE(Parse({"--version"}).WantsVersion());
}

TEST(CommandLineTest, VersionFlagDoesNotImplyConfig) {
  const auto cmd = Parse({"-v"});
  EXPECT_FALSE(cmd.HasConfig());
  EXPECT_TRUE(cmd.ConfigPath().empty());
}

// RTOS_TEST_CONFIG_FILE is injected by test/unittest/CMakeLists.txt: CLI11
// validates existence during parsing (CLI::ExistingFile), so the test needs a
// path that really resolves.
TEST(CommandLineTest, ConfigPathIsCaptured) {
  const auto cmd = Parse({"-c", RTOS_TEST_CONFIG_FILE});
  EXPECT_TRUE(cmd.HasConfig());
  EXPECT_EQ(cmd.ConfigPath(), RTOS_TEST_CONFIG_FILE);
  EXPECT_FALSE(cmd.WantsVersion());
}

TEST(CommandLineTest, LongConfigFlagMatchesShortOne) {
  EXPECT_EQ(Parse({"--config", RTOS_TEST_CONFIG_FILE}).ConfigPath(), Parse({"-c", RTOS_TEST_CONFIG_FILE}).ConfigPath());
}

// Terminal requests cannot be observed in-process: cli.cc calls std::exit() so
// the process is already leaving. A death test is the only way to check one.
// Malformed input takes the same branch, but the exact status is CLI11's to
// choose (its ExitCodes are not part of the interface here), so only the
// documented success case is asserted.
TEST(CommandLineTest, HelpExitsSuccessfully) {
  EXPECT_EXIT(
      {
        const auto cmd = Parse({"-h"});
        (void)cmd;  // [[nodiscard]]: the death test never looks at it
      },
      ::testing::ExitedWithCode(0), "");
}

}  // namespace
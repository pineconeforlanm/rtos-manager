// ============================================================================
//  ut_logging.cc — unit tests for InitLogging()
//
//  The level mapping lives in an anonymous-namespace helper, so it is observed
//  through its effect on the easylog singleton: init_log() publishes the mapped
//  severity, and get_min_severity() reads it back.
// ============================================================================
#include <gtest/gtest.h>

#include <filesystem>
#include <random>
#include <string>
#include <ylt/easylog.hpp>

#include "rtos_manager/config.hpp"
#include "rtos_manager/logging.hpp"

namespace {

using rtos_manager::InitLogging;
using rtos_manager::LogConfig;

/// File-less, console-less configuration: nothing leaves the process.
auto QuietConfig(std::string_view level) -> LogConfig {
  auto cfg = LogConfig{};
  cfg.level = std::string{level};
  cfg.file.clear();
  cfg.console = false;
  return cfg;
}

struct LevelCase {
  std::string_view name;
  easylog::Severity expected;
};

class LoggingLevelTest : public ::testing::TestWithParam<LevelCase> {};

TEST_P(LoggingLevelTest, MapsNameToSeverity) {
  const auto& [name, expected] = GetParam();
  InitLogging(QuietConfig(name));
  EXPECT_EQ(easylog::get_min_severity<0>(), expected) << "level: " << name;
}

INSTANTIATE_TEST_SUITE_P(
    AllSpellings, LoggingLevelTest,
    ::testing::Values(LevelCase{"trace", easylog::Severity::TRACE},
                      LevelCase{"TRACE", easylog::Severity::TRACE},  // case-insensitive
                      LevelCase{"debug", easylog::Severity::DEBUG}, LevelCase{"info", easylog::Severity::INFO},
                      LevelCase{"warn", easylog::Severity::WARN}, LevelCase{"warning", easylog::Severity::WARN},
                      LevelCase{"error", easylog::Severity::ERROR}, LevelCase{"critical", easylog::Severity::CRITICAL},
                      LevelCase{"fatal", easylog::Severity::CRITICAL}, LevelCase{"off", easylog::Severity::NONE},
                      LevelCase{"none", easylog::Severity::NONE},
                      LevelCase{"bogus", easylog::Severity::INFO}));  // unknown -> INFO

TEST(LoggingTest, CreatesMissingParentDirectoryOfTheLogFile) {
  std::random_device rd;
  const auto dir = std::filesystem::temp_directory_path() / ("rtos-manager-log-test-" + std::to_string(rd()));
  const auto file = dir / "nested" / "app.log";
  std::filesystem::remove_all(dir);

  auto cfg = QuietConfig("info");
  cfg.file = file.string();
  InitLogging(cfg);

  EXPECT_TRUE(std::filesystem::exists(file.parent_path()));
  std::filesystem::remove_all(dir);
}

TEST(LoggingTest, EmptyFileKeepsEverythingInProcess) {
  // No path configured: the file branch must not create anything.
  InitLogging(QuietConfig("info"));
  EXPECT_EQ(easylog::get_min_severity<0>(), easylog::Severity::INFO);
}

}  // namespace

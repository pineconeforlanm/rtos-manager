// ============================================================================
//  ut_config.cc — unit tests for the YAML -> struct mapping (glaze).
//
//  Verifies that glaze's compile-time reflection populates the nested
//  ServerConfig / LogConfig aggregates from a YAML document.
// ============================================================================
#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <random>
#include <string>

#include "rtos_manager/config.hpp"

namespace {

// Writes `content` to a uniquely-named temporary file and returns its path.
std::string WriteTempYaml(const std::string& content) {
  std::random_device rd;
  const auto path = std::filesystem::temp_directory_path() /
                    ("rtos-manager-config-test-" + std::to_string(rd()) + ".yaml");
  std::ofstream out(path);
  out << content;
  out.close();
  return path.string();
}

TEST(ConfigTest, ParsesFullDocument) {
  const std::string yaml = R"(
server:
  host: 127.0.0.1
  port: 9090
  io_threads: 4
logging:
  level: debug
  file: /tmp/example.log
  max_size: 2048
  max_files: 3
  console: false
)";
  const auto cfg = rtos_manager::LoadConfig(WriteTempYaml(yaml));

  EXPECT_EQ(cfg.server.host, "127.0.0.1");
  EXPECT_EQ(cfg.server.port, 9090);
  EXPECT_EQ(cfg.server.io_threads, 4u);

  EXPECT_EQ(cfg.logging.level, "debug");
  EXPECT_EQ(cfg.logging.file, "/tmp/example.log");
  EXPECT_EQ(cfg.logging.max_size, 2048u);
  EXPECT_EQ(cfg.logging.max_files, 3u);
  EXPECT_FALSE(cfg.logging.console);
}

TEST(ConfigTest, MissingKeysFallBackToDefaults) {
  // Only `server.port` is provided; everything else keeps the struct defaults.
  const std::string yaml = "server:\n  port: 1234\n";
  const auto cfg = rtos_manager::LoadConfig(WriteTempYaml(yaml));

  EXPECT_EQ(cfg.server.port, 1234);
  EXPECT_EQ(cfg.server.host, "0.0.0.0");
  EXPECT_EQ(cfg.logging.level, "info");
  EXPECT_TRUE(cfg.logging.console);
}

TEST(ConfigTest, ThrowsOnMissingFile) {
  EXPECT_THROW(rtos_manager::LoadConfig("/nonexistent/rtos-manager.yaml"),
               std::runtime_error);
}

}  // namespace

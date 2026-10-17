// ============================================================================
//  ut_version.cc — unit tests for rtos_manager::VersionString()/LogVersion()
//
//  Test naming uses CamelCase to follow the GoogleTest convention adopted
//  here; production code now also uses CamelCase to satisfy
//  readability-identifier-naming.FunctionCase.
// ============================================================================
#include <gtest/gtest.h>

#include <cstddef>
#include <sstream>
#include <string>
#include <string_view>

#include <ylt/easylog.hpp>

#include "rtos_manager/version.hpp"
#include "rtos_manager/version_info.hpp"  // AUTO-GENERATED (rtos_manager::build::*)

namespace {

TEST(VersionTest, VersionStringContainsVersion) {
  const std::string s = rtos_manager::VersionString();
  EXPECT_NE(s.find(rtos_manager::build::kVersionSemver), std::string::npos)
      << "VersionString() should contain the project version: " << s;
}

TEST(VersionTest, VersionStringMentionsGit) {
  const std::string s = rtos_manager::VersionString();
  EXPECT_NE(s.find(" on "), std::string::npos)
      << "VersionString() should mention the git branch: " << s;
}

TEST(VersionTest, VersionStringHasNoTrailingNewline) {
  const std::string s = rtos_manager::VersionString();
  EXPECT_EQ(s.find('\n'), std::string::npos)
      << "VersionString() must be a single line";
}

// Sanity-check the semver string baked in at configure time has the canonical
// "MAJOR.MINOR.PATCH" shape (with optional "-prerel.N"). This guards against
// regressions in cmake/version_info.cmake's regex.
TEST(VersionTest, SemverLooksCanonical) {
  const std::string_view v = rtos_manager::build::kVersionSemver;
  ASSERT_FALSE(v.empty());
  // 1.2.3  or  1.2.3-rc.4  /  -alpha.1  /  -beta.9
  const auto ok = [](std::string_view s) {
    auto is_digit = [](char c) { return c >= '0' && c <= '9'; };
    std::size_t i = 0;
    auto eat_num = [&]() {
      std::size_t start = i;
      while (i < s.size() && is_digit(s[i])) {
        ++i;
      }
      return i > start;
    };
    auto expect = [&](char c) {
      if (i >= s.size() || s[i] != c) {
        return false;
      }
      ++i;
      return true;
    };
    if (!eat_num()) return false;
    if (!expect('.')) return false;
    if (!eat_num()) return false;
    if (!expect('.')) return false;
    if (!eat_num()) return false;
    if (i < s.size() && s[i] == '-') {
      ++i;
      std::size_t start = i;
      while (i < s.size() && s[i] != '.') {
        ++i;
      }
      if (i == start) return false;
      if (!expect('.')) return false;
      if (!eat_num()) return false;
    }
    return i == s.size();
  };
  EXPECT_TRUE(ok(v)) << "kVersionSemver is not in MAJOR.MINOR.PATCH[-pre.N] form: " << v;
}

TEST(VersionTest, LogVersionReportSections) {
  // Route the process-wide logger to console-off / file-off, and attach an
  // extra appender that captures each record's message into `os`.
  std::ostringstream os;
  easylog::init_log<0>(easylog::Severity::INFO, "", /*async=*/false,
                       /*enable_console=*/false);
  easylog::add_appender<0>(
      [&os](easylog::record_t& rec) { os << rec.get_message() << '\n'; });

  rtos_manager::LogVersion();

  const std::string report = os.str();
  EXPECT_NE(report.find(rtos_manager::build::kProjectName), std::string::npos);
  EXPECT_NE(report.find(rtos_manager::build::kProjectDescription), std::string::npos);
  EXPECT_NE(report.find("homepage"), std::string::npos);
  EXPECT_NE(report.find("git "), std::string::npos);
  EXPECT_NE(report.find("build "), std::string::npos);
  EXPECT_NE(report.find("system "), std::string::npos);
  EXPECT_NE(report.find("compiler "), std::string::npos);

  // LogVersion() emits one record per section, so the report is multiline.
  EXPECT_NE(report.find('\n'), std::string::npos);
}

}  // namespace

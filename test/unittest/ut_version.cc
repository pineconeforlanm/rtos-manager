// ============================================================================
//  ut_version.cc — unit tests for rtos_manager::BuildInfo
//
//  Covers the property accessors, the compact ToString() line and the JSON wire
//  format served by GET /api/v1/version.
//  Test names follow the GoogleTest CamelCase convention used across the suite.
// ============================================================================
#include <gtest/gtest.h>

#include <cstddef>
#include <format>
#include <string>
#include <string_view>

#include "rtos_manager/version.hpp"
#include "rtos_manager/version_info.hpp"  // AUTO-GENERATED (rtos_manager::build::kMetadata)

namespace {

using rtos_manager::BuildInfo;

/// MAJOR.MINOR.PATCH[-prerel.N] — mirrors the regex in cmake/version_info.cmake.
auto IsCanonicalSemver(std::string_view s) -> bool {
  auto is_digit = [](char c) -> bool { return c >= '0' && c <= '9'; };
  auto i = std::size_t{0};
  auto eat_number = [&]() -> bool {
    const auto start = i;
    while (i < s.size() && is_digit(s[i])) {
      ++i;
    }
    return i > start;
  };
  auto expect = [&](char c) -> bool {
    if (i >= s.size() || s[i] != c) {
      return false;
    }
    ++i;
    return true;
  };

  if (!eat_number()) return false;
  if (!expect('.')) return false;
  if (!eat_number()) return false;
  if (!expect('.')) return false;
  if (!eat_number()) return false;
  if (i < s.size() && s[i] == '-') {
    ++i;
    const auto start = i;
    while (i < s.size() && s[i] != '.') {
      ++i;
    }
    if (i == start) return false;
    if (!expect('.')) return false;
    if (!eat_number()) return false;
  }
  return i == s.size();
}

TEST(BuildInfoTest, ToStringContainsSemver) {
  const auto& info = BuildInfo::Get();
  const auto text = info.ToString();
  EXPECT_NE(text.find(info.Semver()), std::string::npos) << "ToString() should contain the project version: " << text;
}

TEST(BuildInfoTest, ToStringMentionsGitBranch) {
  const auto text = BuildInfo::Get().ToString();
  EXPECT_NE(text.find(" on "), std::string::npos) << "ToString() should mention the git branch: " << text;
}

TEST(BuildInfoTest, ToStringIsSingleLine) {
  const auto text = BuildInfo::Get().ToString();
  EXPECT_EQ(text.find('\n'), std::string::npos) << "ToString() must be a single line";
}

// The typed accessors must agree with the rendered semver string, so a
// regression in either the CMake regex or the generated header surfaces here
// instead of in the JSON response.
TEST(BuildInfoTest, AccessorsMatchSemver) {
  const auto& info = BuildInfo::Get();
  const auto prefix = std::format("{}.{}.{}", info.VersionMajor(), info.VersionMinor(), info.VersionPatch());
  EXPECT_TRUE(info.Semver().starts_with(prefix))
      << "semver '" << info.Semver() << "' does not start with '" << prefix << "'";
  EXPECT_EQ(info.IsPrerelease(), !info.PreRelease().empty());
  EXPECT_EQ(info.IsPrerelease(), info.Semver().contains('-'));
}

TEST(BuildInfoTest, SemverLooksCanonical) {
  const auto v = rtos_manager::build::kMetadata.version.semver;
  ASSERT_FALSE(v.empty());
  EXPECT_TRUE(IsCanonicalSemver(v)) << "kMetadata.version.semver is not in MAJOR.MINOR.PATCH[-pre.N] form: " << v;
}

TEST(BuildInfoTest, JsonCarriesDocumentedKeys) {
  const auto json = BuildInfo::Get().ToJson();
  ASSERT_FALSE(json.empty());
  EXPECT_EQ(json.front(), '{');
  EXPECT_EQ(json.back(), '}');

  // Keys required by api/openapi.yaml#/components/schemas/VersionInfo.
  for (const auto* key : {"project", "version", "prerelease", "gitHash", "commitCount", "buildType", "cxxStandard"}) {
    const auto needle = std::format("\"{}\":", key);
    EXPECT_NE(json.find(needle), std::string::npos) << "missing " << needle << " in " << json;
  }
  EXPECT_NE(json.find(BuildInfo::Get().Semver()), std::string::npos);
}

}  // namespace

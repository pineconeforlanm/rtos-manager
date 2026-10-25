// ============================================================================
//  version.cc — implementation of the BuildInfo façade.
//
//  The accessors are inline constexpr forwards declared in version.hpp, so only
//  what cannot live in a header is left here: the single instance, the JSON wire
//  shape and the two renderings. No logging happens here — callers own the
//  output stream.
// ============================================================================
#include "rtos_manager/version.hpp"

#include <format>
#include <glaze/glaze.hpp>
#include <string>
#include <string_view>
#include <tuple>

namespace rtos_manager {

/// JSON wire shape of GET /api/v1/version, mirroring
/// api/openapi.yaml#/components/schemas/VersionInfo. Glaze maps member names to
/// JSON keys 1:1 through aggregate reflection (no glz::meta, no format string),
/// so this struct *is* the contract: keep it and the OpenAPI schema in sync.
struct BuildInfo::Document {
  std::string_view project;
  std::string_view description;
  std::string_view homepage;
  std::string_view version;
  int major{};
  int minor{};
  int patch{};
  std::string_view preRelease;  ///< "", "alpha", "beta" or "rc"
  bool prerelease{};
  std::string_view gitHash;
  std::string_view gitShortHash;
  std::string_view branch;
  std::string_view tag;
  std::string_view describe;
  int commitCount{};
  std::string_view commitDate;
  bool dirty{};
  std::string_view buildType;
  std::string_view buildTime;
  std::string_view system;
  std::string_view systemVersion;
  std::string_view processor;
  std::string compiler;     ///< "<id> <version>", e.g. "GNU 16.2.0"
  std::string cxxStandard;  ///< a string in the contract: "26"
};

// --- Lifecycle --------------------------------------------------------------
auto BuildInfo::Get() noexcept -> const BuildInfo& {
  static const BuildInfo instance;
  return instance;
}

// --- Rendering --------------------------------------------------------------
auto BuildInfo::ToString() const -> std::string {
  return std::format("{} ({} on {}{})", Semver(), GitHashShort(), GitBranch(), IsDirty() ? ", dirty" : "");
}

auto BuildInfo::ToJson() const -> std::string {
  const auto document = Document{
      .project = ProjectName(),
      .description = ProjectDescription(),
      .homepage = ProjectHomepage(),
      .version = Semver(),
      .major = VersionMajor(),
      .minor = VersionMinor(),
      .patch = VersionPatch(),
      .preRelease = PreRelease(),
      .prerelease = IsPrerelease(),
      .gitHash = GitHash(),
      .gitShortHash = GitHashShort(),
      .branch = GitBranch(),
      .tag = GitTag(),
      .describe = GitDescribe(),
      .commitCount = CommitCount(),
      .commitDate = CommitDate(),
      .dirty = IsDirty(),
      .buildType = BuildType(),
      .buildTime = BuildTimestamp(),
      .system = SystemName(),
      .systemVersion = SystemVersion(),
      .processor = Processor(),
      .compiler = std::format("{} {}", CompilerId(), CompilerVersion()),
      .cxxStandard = std::format("{}", CxxStandard()),
  };

  auto json = std::string{};
  // Every member except `compiler`/`cxxStandard` is a scalar or a string_view,
  // so the writer has no failure path here and fills the buffer in place.
  std::ignore = glz::write_json(document, json);
  return json;
}

}  // namespace rtos_manager
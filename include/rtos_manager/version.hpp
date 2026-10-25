// ============================================================================
//  rtos_manager/version.hpp — public build/version metadata API
//
//  The concrete values are generated at configure time into
//  <build>/generated/rtos_manager/version_info.hpp (see cmake/version_info.cmake)
//  and installed next to this header, so the accessors below are inline
//  constexpr forwards to rtos_manager::build::kMetadata — callers never need to
//  spell out the generated namespace themselves.
// ============================================================================
#pragma once

#include <string>
#include <string_view>

#include "rtos_manager/version_info.hpp"  // AUTO-GENERATED

namespace rtos_manager {

/// Read-only façade over the metadata baked into the binary.
///
/// Stateless and literal: every accessor forwards to the generated constexpr
/// data and folds away at compile time, so there is exactly one instance
/// (Get()) and nothing to construct, copy or keep alive.
/// The class owns data and its representations only — it never writes to a
/// logger or a stream; callers decide where the text goes:
///   * ToString() — compact single line (startup log, `-v`)
///   * ToReport() — full labelled report (`--version`, bug reports)
///   * ToJson()   — body of GET /api/v1/version (see api/openapi.yaml)
class BuildInfo {
 public:
  /// The single, stateless instance.
  [[nodiscard]] static auto Get() noexcept -> const BuildInfo&;

  // --- Project ---------------------------------------------------------------
  [[nodiscard]] constexpr auto ProjectName() const noexcept -> std::string_view {
    return build::kMetadata.project.name;
  }
  [[nodiscard]] constexpr auto ProjectDescription() const noexcept -> std::string_view {
    return build::kMetadata.project.description;
  }
  [[nodiscard]] constexpr auto ProjectHomepage() const noexcept -> std::string_view {
    return build::kMetadata.project.homepage;
  }

  // --- Semantic version (parsed from the latest git tag) ---------------------
  [[nodiscard]] constexpr auto Semver() const noexcept -> std::string_view { return build::kMetadata.version.semver; }
  [[nodiscard]] constexpr auto VersionMajor() const noexcept -> int { return build::kMetadata.version.major; }
  [[nodiscard]] constexpr auto VersionMinor() const noexcept -> int { return build::kMetadata.version.minor; }
  [[nodiscard]] constexpr auto VersionPatch() const noexcept -> int { return build::kMetadata.version.patch; }
  [[nodiscard]] constexpr auto PreRelease() const noexcept -> std::string_view {
    return build::kMetadata.version.preRelease;
  }
  [[nodiscard]] constexpr auto PreReleaseNumber() const noexcept -> int { return build::kMetadata.version.preNum; }
  /// Derived from PreRelease(), not stored separately in the metadata.
  [[nodiscard]] constexpr auto IsPrerelease() const noexcept -> bool { return build::kMetadata.version.IsPrerelease(); }

  // --- Git provenance --------------------------------------------------------
  [[nodiscard]] constexpr auto GitDescribe() const noexcept -> std::string_view {
    return build::kMetadata.git.describe;
  }
  [[nodiscard]] constexpr auto GitHash() const noexcept -> std::string_view { return build::kMetadata.git.hash; }
  [[nodiscard]] constexpr auto GitHashShort() const noexcept -> std::string_view {
    return build::kMetadata.git.hashShort;
  }
  [[nodiscard]] constexpr auto GitBranch() const noexcept -> std::string_view { return build::kMetadata.git.branch; }
  [[nodiscard]] constexpr auto GitTag() const noexcept -> std::string_view { return build::kMetadata.git.tag; }
  [[nodiscard]] constexpr auto CommitCount() const noexcept -> int { return build::kMetadata.git.commitCount; }
  [[nodiscard]] constexpr auto CommitDate() const noexcept -> std::string_view {
    return build::kMetadata.git.commitDate;
  }
  [[nodiscard]] constexpr auto IsDirty() const noexcept -> bool { return build::kMetadata.git.dirty; }

  // --- Build / toolchain -----------------------------------------------------
  [[nodiscard]] constexpr auto BuildType() const noexcept -> std::string_view { return build::kMetadata.build.type; }
  [[nodiscard]] constexpr auto BuildTimestamp() const noexcept -> std::string_view {
    return build::kMetadata.build.timestamp;
  }
  [[nodiscard]] constexpr auto CxxStandard() const noexcept -> int { return build::kMetadata.build.cxxStandard; }

  // --- Host system -----------------------------------------------------------
  [[nodiscard]] constexpr auto SystemName() const noexcept -> std::string_view { return build::kMetadata.host.system; }
  [[nodiscard]] constexpr auto SystemVersion() const noexcept -> std::string_view {
    return build::kMetadata.host.version;
  }
  [[nodiscard]] constexpr auto Processor() const noexcept -> std::string_view {
    return build::kMetadata.host.processor;
  }

  // --- Compiler --------------------------------------------------------------
  [[nodiscard]] constexpr auto CompilerId() const noexcept -> std::string_view { return build::kMetadata.compiler.id; }
  [[nodiscard]] constexpr auto CompilerVersion() const noexcept -> std::string_view {
    return build::kMetadata.compiler.version;
  }

  // --- Rendering -------------------------------------------------------------
  /// Compact single line, e.g. "0.1.1 (f683f7b on develop, dirty)".
  [[nodiscard]] auto ToString() const -> std::string;
  /// Full label-aligned report, one field per line, terminated by a newline —
  /// the `--version` output. Plain text on purpose: no log prefixes, so the
  /// result stays greppable and diff-stable.
  [[nodiscard]] auto ToReport() const -> std::string;
  /// JSON body of GET /api/v1/version; the keys mirror
  /// api/openapi.yaml#/components/schemas/VersionInfo.
  [[nodiscard]] auto ToJson() const -> std::string;

 private:
  /// JSON wire shape (defined in version.cc; Glaze maps its members to keys).
  struct Document;

  constexpr BuildInfo() noexcept = default;
};

}  // namespace rtos_manager

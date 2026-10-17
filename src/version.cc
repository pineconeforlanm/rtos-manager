// ============================================================================
//  version.cc — exposes the compile-time generated metadata.
// ============================================================================
#include "rtos_manager/version.hpp"

#include <format>

#include <ylt/easylog.hpp>

#include "rtos_manager/version_info.hpp"  // AUTO-GENERATED

namespace rtos_manager {

std::string VersionString() {
  const std::string dirty = build::kGitDirty ? ", dirty" : "";
  return std::format("{} ({} on {}{})",
                     build::kVersionSemver,
                     build::kGitHashShort,
                     build::kGitBranch,
                     dirty);
}

void LogVersion() {
  ELOGFMT(INFO, "{} {}", build::kProjectName, build::kVersionSemver);
  ELOGFMT(INFO, "  description : {}", build::kProjectDescription);
  ELOGFMT(INFO, "  homepage    : {}", build::kHomepageUrl);
  ELOGFMT(INFO, "  git         : {} [hash={} branch={} tag={} commits={} dirty={} date={}]",
          build::kGitDescribe, build::kGitHash, build::kGitBranch,
          build::kGitTag, build::kGitCommitCount,
          build::kGitDirty ? "true" : "false", build::kGitCommitDate);
  ELOGFMT(INFO, "  build       : type={} time={} UTC",
          build::kBuildType, build::kBuildTime);
  ELOGFMT(INFO, "  system      : {} {} ({})",
          build::kSystemName, build::kSystemVersion, build::kSystemProcessor);
  ELOGFMT(INFO, "  compiler    : {} {} (C++{})",
          build::kCompilerId, build::kCompilerVersion, build::kCxxStandard);
}

}  // namespace rtos_manager

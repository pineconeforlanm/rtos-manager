# ============================================================================
#  cmake/changelog.cmake — git-cliff integration (optional)
#
#  Adds custom targets:
#    changelog           — regenerate CHANGELOG.md (full history)
#    changelog-unreleased — preview unreleased commits (stdout only)
#
#  No-ops gracefully when `git-cliff` is not found on PATH.
# ============================================================================

find_program(GIT_CLIFF_EXECUTABLE NAMES git-cliff)

if(NOT GIT_CLIFF_EXECUTABLE)
  message(STATUS "git-cliff not found — 'changelog' targets will be no-ops")
  # Create dummy targets that print a helpful message.
  add_custom_target(changelog
    COMMAND ${CMAKE_COMMAND} -E echo
      "SKIP: git-cliff not installed. See https://git-cliff.org/docs/installation"
    VERBATIM)
  add_custom_target(changelog-unreleased
    COMMAND ${CMAKE_COMMAND} -E echo
      "SKIP: git-cliff not installed."
    VERBATIM)
  return()
endif()

# Path to cliff.toml at the project root.
set(_RTOS_CLIFF_CONFIG "${CMAKE_SOURCE_DIR}/cliff.toml")
set(_RTOS_CHANGELOG    "${CMAKE_SOURCE_DIR}/CHANGELOG.md")

# --- changelog: regenerate the full file ------------------------------------
# --offline keeps generation deterministic: the template's `commit.remote.*`
# references otherwise make git-cliff query the GitHub API for author handles,
# and a timeout there aborts the run (panic) instead of writing the file. The
# changelog is built from local history only, so no metadata is needed.
#
# DESTRUCTIVE: this rewrites CHANGELOG.md from scratch, so the curated sections
# of the releases already published are replaced by their terse skeletons. Use
# it only to bootstrap a new file or to recover a lost one — a normal release
# adds one section (changelog-unreleased, then paste).
add_custom_target(changelog
  COMMAND "${GIT_CLIFF_EXECUTABLE}"
    --config "${_RTOS_CLIFF_CONFIG}"
    --offline
    --output "${_RTOS_CHANGELOG}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Regenerating CHANGELOG.md via git-cliff (destructive)"
  VERBATIM
)

# --- changelog-unreleased: the section for the version being prepared --------
# CHANGELOG.md is curated prose: the release commit takes this generated section,
# enriches it from the commit bodies and pastes it below the header. Only the
# new section is emitted (`--strip header`), because a full regeneration would
# replace every earlier hand-written section with its terse skeleton.
add_custom_target(changelog-unreleased
  COMMAND "${GIT_CLIFF_EXECUTABLE}"
    --config "${_RTOS_CLIFF_CONFIG}"
    --offline
    --unreleased
    --strip header
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Previewing the next CHANGELOG section (git-cliff)"
  VERBATIM
)

message(STATUS "git-cliff found: ${GIT_CLIFF_EXECUTABLE} — 'changelog' targets enabled")

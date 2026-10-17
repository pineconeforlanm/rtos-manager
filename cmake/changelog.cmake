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
add_custom_target(changelog
  COMMAND "${GIT_CLIFF_EXECUTABLE}"
    --config "${_RTOS_CLIFF_CONFIG}"
    --output "${_RTOS_CHANGELOG}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Generating CHANGELOG.md via git-cliff"
  VERBATIM
)

# --- changelog-unreleased: preview what the next section will look like ------
add_custom_target(changelog-unreleased
  COMMAND "${GIT_CLIFF_EXECUTABLE}"
    --config "${_RTOS_CLIFF_CONFIG}"
    --unreleased
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Previewing unreleased changes (git-cliff)"
  VERBATIM
)

message(STATUS "git-cliff found: ${GIT_CLIFF_EXECUTABLE} — 'changelog' targets enabled")

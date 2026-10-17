# ============================================================================
#  version_info.cmake — collect Git + system + build metadata at configure
#  time and generate <build>/generated/rtos_manager/version_info.hpp.
#
#  The generated header is compiled into every target, so information such as
#  commit hash, branch, tag, build type, compiler and host architecture is
#  baked into the final binary (surfaced by `--version`).
#
#  Semantic versioning (semver 2.0.0):
#    - Source of truth = the most recent `vX.Y.Z[-prerel.N]` annotated tag.
#    - Falls back to project(... VERSION ...) when no tag exists.
#    - Outputs: RTOS_VERSION_SEMVER / _MAJOR / _MINOR / _PATCH
#               RTOS_VERSION_PRE_RELEASE / _PRE_NUM
#               RTOS_PACKAGE_DIRTYSUFFIX (for CPack file naming)
#  Note: PROJECT_VERSION* CMake variables are NOT overwritten (that is a
#  fragile pattern from the legacy template project); instead custom RTOS_*
#  variables flow into the configure_file templates.
# ============================================================================
find_package(Git QUIET)

# --- Defaults (used when .git is absent or git CLI missing) ----------------
set(RTOS_GIT_HASH          "unknown")
set(RTOS_GIT_HASH_SHORT    "unknown")
set(RTOS_GIT_BRANCH        "unknown")
set(RTOS_GIT_TAG           "unknown")
set(RTOS_GIT_COMMIT_COUNT  "0")
set(RTOS_GIT_COMMIT_DATE   "unknown")
set(RTOS_GIT_DIRTY         "false")
set(RTOS_GIT_DESCRIBE      "unknown")

# --- Gather raw Git info ---------------------------------------------------
if(GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
  execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_HASH OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_HASH_SHORT OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_BRANCH OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --abbrev=0
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_TAG OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_DESCRIBE OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} rev-list --count HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_COMMIT_COUNT OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} log -1 --format=%cI HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE RTOS_GIT_COMMIT_DATE OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  execute_process(COMMAND ${GIT_EXECUTABLE} status --porcelain
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE _RTOS_GIT_STATUS OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  if(_RTOS_GIT_STATUS STREQUAL "")
    set(RTOS_GIT_DIRTY "false")
  else()
    set(RTOS_GIT_DIRTY "true")
  endif()
  message(STATUS "Git info: ${RTOS_GIT_DESCRIBE} (${RTOS_GIT_HASH_SHORT} on ${RTOS_GIT_BRANCH}, dirty=${RTOS_GIT_DIRTY})")
else()
  message(STATUS "Git repository not detected — version info will show 'unknown'")
endif()

# --- Semver parsing ---------------------------------------------------------
# Accepts  v?X.Y.Z[-alpha.N | -beta.N | -rc.N]  (the leading "v" is stripped).
# When no tag is present, falls back to project(... VERSION x.y.z).
function(rtos_parse_semver tag_string out_prefix)
  set(_maj 0)
  set(_min 0)
  set(_pat 0)
  set(_pre "")
  set(_prenum 0)
  string(REGEX REPLACE "^v" "" _v "${tag_string}")
  if(_v MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)-(alpha|beta|rc)\\.([0-9]+)$")
    set(_maj    ${CMAKE_MATCH_1})
    set(_min    ${CMAKE_MATCH_2})
    set(_pat    ${CMAKE_MATCH_3})
    set(_pre    ${CMAKE_MATCH_4})
    set(_prenum ${CMAKE_MATCH_5})
  elseif(_v MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
    set(_maj ${CMAKE_MATCH_1})
    set(_min ${CMAKE_MATCH_2})
    set(_pat ${CMAKE_MATCH_3})
  else()
    # Not a recognised semver tag — fall back to project VERSION, warn.
    message(STATUS "RTOS semver parse: tag '${tag_string}' is not v?X.Y.Z[-pre.N]; "
                   "using project VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
    set(_maj ${PROJECT_VERSION_MAJOR})
    set(_min ${PROJECT_VERSION_MINOR})
    set(_pat ${PROJECT_VERSION_PATCH})
  endif()
  set(${out_prefix}_MAJOR     "${_maj}"   PARENT_SCOPE)
  set(${out_prefix}_MINOR     "${_min}"   PARENT_SCOPE)
  set(${out_prefix}_PATCH     "${_pat}"   PARENT_SCOPE)
  set(${out_prefix}_PRE       "${_pre}"   PARENT_SCOPE)
  set(${out_prefix}_PRE_NUM   "${_prenum}" PARENT_SCOPE)
endfunction()

rtos_parse_semver("${RTOS_GIT_TAG}" RTOS_VERSION)

# Build the canonical semver string ("1.2.3" or "1.2.3-rc.4").
if(RTOS_VERSION_PRE STREQUAL "")
  set(RTOS_VERSION_SEMVER "${RTOS_VERSION_MAJOR}.${RTOS_VERSION_MINOR}.${RTOS_VERSION_PATCH}")
  set(RTOS_VERSION_IS_PRERELEASE "false")
else()
  set(RTOS_VERSION_SEMVER
      "${RTOS_VERSION_MAJOR}.${RTOS_VERSION_MINOR}.${RTOS_VERSION_PATCH}-${RTOS_VERSION_PRE}.${RTOS_VERSION_PRE_NUM}")
  set(RTOS_VERSION_IS_PRERELEASE "true")
endif()
set(RTOS_VERSION_PRE_RELEASE "${RTOS_VERSION_PRE}")
set(RTOS_VERSION_PRE_NUM     "${RTOS_VERSION_PRE_NUM}")

# Suffix appended to the CPack artifact name when working tree is dirty.
if(RTOS_GIT_DIRTY STREQUAL "true")
  set(RTOS_PACKAGE_DIRTYSUFFIX "-dirty")
else()
  set(RTOS_PACKAGE_DIRTYSUFFIX "")
endif()

message(STATUS "RTOS semantic version: ${RTOS_VERSION_SEMVER} (pre-release=${RTOS_VERSION_IS_PRERELEASE})")

# --- System / toolchain / build metadata -----------------------------------
string(TIMESTAMP RTOS_BUILD_TIME "%Y-%m-%d %H:%M:%S" UTC)
set(RTOS_BUILD_TYPE    "${CMAKE_BUILD_TYPE}")
set(RTOS_SYSTEM_NAME   "${CMAKE_SYSTEM_NAME}")
set(RTOS_SYSTEM_VER    "${CMAKE_SYSTEM_VERSION}")
set(RTOS_SYSTEM_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
set(RTOS_COMPILER_ID   "${CMAKE_CXX_COMPILER_ID}")
set(RTOS_COMPILER_VER  "${CMAKE_CXX_COMPILER_VERSION}")
set(RTOS_EFFECTIVE_CXX_STD "${CMAKE_CXX_STANDARD}")

# --- Generate the header ----------------------------------------------------
set(RTOS_GENERATED_INCLUDE_DIR "${CMAKE_BINARY_DIR}/generated")
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/version_info.hpp.in"
  "${RTOS_GENERATED_INCLUDE_DIR}/rtos_manager/version_info.hpp"
  @ONLY)

message(STATUS "Generated version header: ${RTOS_GENERATED_INCLUDE_DIR}/rtos_manager/version_info.hpp")

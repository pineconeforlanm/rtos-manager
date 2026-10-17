# ============================================================================
#  rtos-manager — top-level CMake configuration
#
#  Toolchain: CMake + Conan 2 + GCC/G++ + gcovr + Doxygen + OpenAPI
#  Branch model: Git Flow (see CONTRIBUTING.md)
# ============================================================================
cmake_minimum_required(VERSION 3.28)

# ---------------------------------------------------------------------------
# Project metadata (single source of truth for the version).
# Bump these on a release commit; version info is injected into the binary.
# ---------------------------------------------------------------------------
project(
  rtos_manager
  VERSION 0.1.1
  DESCRIPTION "RTOS Manager — an HTTP service for managing RTOS devices"
  HOMEPAGE_URL "https://github.com/pineconeforlanm/rtos-manager"
  LANGUAGES CXX C)

# ---------------------------------------------------------------------------
# Make our own CMake modules available and pick up Conan's generated files.
# ---------------------------------------------------------------------------
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# ---------------------------------------------------------------------------
# Build / feature options (overridable via CMakePresets or -D...)
# ---------------------------------------------------------------------------
option(RTOS_ENABLE_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(RTOS_ENABLE_TESTS              "Build unit tests (CTest)"          ON)
option(RTOS_ENABLE_COVERAGE           "Enable gcov/gcovr coverage"        OFF)
option(RTOS_ENABLE_DOCS               "Build Doxygen documentation"       OFF)
option(RTOS_ENABLE_EXAMPLES           "Build examples"                    OFF)
option(RTOS_ENABLE_BENCH              "Build benchmarks"                  OFF)
option(RTOS_ENABLE_PROTOBUF           "Build protobuf/OpenAPI contracts"  OFF)

# Default to Release when no build type is set (single-config generators).
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "No build type specified, defaulting to 'Release'")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
               Debug Release RelWithDebInfo MinSizeRel)
endif()

# ---------------------------------------------------------------------------
# Compiler / language settings  (C++ standard, reflection, warnings, opt)
# ---------------------------------------------------------------------------
include(compiler_options)

# ---------------------------------------------------------------------------
# Git + system + build metadata -> generated version_info.hpp injected into
# every target. Provides --version output baked into the binary.
# ---------------------------------------------------------------------------
include(version_info)

# ---------------------------------------------------------------------------
# Optional coverage instrumentation (must run before targets are added).
# ---------------------------------------------------------------------------
include(coverage)

# ---------------------------------------------------------------------------
# Developer conveniences: clang-format / clang-tidy custom targets
# (`format`, `format-check`, `tidy`). No-op when the tools are not present.
# ---------------------------------------------------------------------------
include(format)

# ---------------------------------------------------------------------------
# Changelog generation via git-cliff (targets: `changelog`,
# `changelog-unreleased`). No-op when git-cliff is absent from PATH.
# ---------------------------------------------------------------------------
include(changelog)

# ---------------------------------------------------------------------------
# OpenAPI contract validation / HTML rendering (api/openapi.yaml). Targets
# (`openapi`, `openapi-validate`, `openapi-docs`) no-op when npx is absent.
# ---------------------------------------------------------------------------
include(openapi)

# ---------------------------------------------------------------------------
# Export compile_commands.json and link it into the source root so clangd /
# other LSP servers can index the project regardless of the active preset.
# ---------------------------------------------------------------------------
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# Re-create the link every configure so switching presets (debug <-> release,
# which point the link at different build dirs) never trips CREATE_LINK on an
# already-existing symlink.
file(REMOVE "${CMAKE_SOURCE_DIR}/compile_commands.json")
file(CREATE_LINK "${CMAKE_BINARY_DIR}/compile_commands.json"
     "${CMAKE_SOURCE_DIR}/compile_commands.json" SYMBOLIC)

# ---------------------------------------------------------------------------
# Dependencies.
#   * Conan provides: glaze (config), CLI11 (cli), gtest/benchmark (test).
#   * yalantinglibs (coro_http + easylog) is vendored under thirdparty/ via a
#     git submodule and exposed through the header-only target rtos::ylt.
# ---------------------------------------------------------------------------
find_package(glaze CONFIG REQUIRED)   # YAML/JSON config reflection (glaze::glaze)
find_package(CLI11 CONFIG REQUIRED)   # command-line parsing (CLI11::CLI11)

if(RTOS_ENABLE_TESTS)
  find_package(GTest CONFIG REQUIRED)     # GTest::gtest / GTest::gtest_main
endif()
if(RTOS_ENABLE_BENCH)
  find_package(benchmark CONFIG REQUIRED) # benchmark::benchmark / benchmark::benchmark_main
endif()

# ---------------------------------------------------------------------------
# Sub-directories
# ---------------------------------------------------------------------------
add_subdirectory(thirdparty)  # rtos::ylt (coro_http + easylog), header-only

add_subdirectory(src)

if(RTOS_ENABLE_TESTS)
  enable_testing()
  add_subdirectory(test)
endif()

if(RTOS_ENABLE_EXAMPLES)
  add_subdirectory(example)
endif()

if(RTOS_ENABLE_BENCH)
  add_subdirectory(bench)
endif()

if(RTOS_ENABLE_DOCS)
  add_subdirectory(docs)
endif()

# protos/ and thirdparty/ are reserved for future features — wired lazily so
# the skeleton builds cleanly today.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/protos/CMakeLists.txt" AND RTOS_ENABLE_PROTOBUF)
  add_subdirectory(protos)
endif()

# ---------------------------------------------------------------------------
# Packaging: systemd unit + CPack (Linux only). Included last so every
# install() rule above is visible to CPack. `cmake --build <dir> --target
# package` (or `cpack -G DEB`) produces the .deb.
# ---------------------------------------------------------------------------
include(packaging)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
message(STATUS "----------------------------------------------------------------")
message(STATUS " ${PROJECT_NAME} ${PROJECT_VERSION} configuration summary")
message(STATUS "   build type ........ ${CMAKE_BUILD_TYPE}")
message(STATUS "   C++ standard ...... ${CMAKE_CXX_STANDARD}")
message(STATUS "   reflection ........ ${RTOS_ENABLE_REFLECTION}")
message(STATUS "   hardening ......... ${RTOS_ENABLE_HARDENING}")
message(STATUS "   LTO ............... ${RTOS_ENABLE_LTO}")
message(STATUS "   warnings-as-error . ${RTOS_ENABLE_WARNINGS_AS_ERRORS}")
message(STATUS "   tests ............. ${RTOS_ENABLE_TESTS}")
message(STATUS "   coverage .......... ${RTOS_ENABLE_COVERAGE}")
message(STATUS "   docs .............. ${RTOS_ENABLE_DOCS}")
message(STATUS "   install prefix .... ${CMAKE_INSTALL_PREFIX}")
message(STATUS "----------------------------------------------------------------")

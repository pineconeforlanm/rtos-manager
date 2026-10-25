# ============================================================================
#  project_setup.cmake — single entry point for all configure-time setup.
#
#  The top-level CMakeLists.txt deliberately stays declarative: it declares
#  the project and the build graph, then includes exactly two hooks —
#    project_setup.cmake     (this file, before any target exists)
#    project_finalize.cmake  (after the targets: packaging + summary)
#
#  Everything below runs in order; the ordering is load-bearing:
#    1. switches              consumed by the toolchain / dependency modules
#    2. toolchain policy      must precede dependencies (rtos::stdcxx_exp)
#    3. generated metadata    version_info.hpp / compile_commands.json
#    4. instrumentation       coverage flags must precede all targets
#    5. dependencies          Conan packages + vendored yalantinglibs
#    6. developer tooling     format / changelog / openapi custom targets
# ============================================================================

# Make this directory the module path so `include(<module>)` resolves to
# cmake/<module>.cmake from anywhere in the project.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# --- 1. Switches ------------------------------------------------------------
include(build_options)      # RTOS_ENABLE_* switches + default build type

# --- 2. Toolchain policy ----------------------------------------------------
include(compiler_options)   # C++ standard, reflection, warnings, opt, hardening

# --- 3. Generated / IDE metadata -------------------------------------------
include(version_info)       # git/system metadata -> generated version_info.hpp
include(compile_commands)   # compile_commands.json + source-root symlink

# --- 4. Instrumentation -----------------------------------------------------
include(coverage)           # gcov/gcovr (before any target is defined)

# --- 5. Dependencies --------------------------------------------------------
include(dependencies)       # Conan packages + vendored yalantinglibs (rtos::ylt)

# --- 6. Developer tooling (no-op when the tools are absent) -----------------
# Formatting and linting are NOT CMake targets: they live in scripts/
# (format.sh / lint.sh) and run from the git hooks, so the build graph stays
# free of developer tooling.
include(changelog)          # changelog / changelog-unreleased
include(openapi)            # openapi / openapi-validate / openapi-docs

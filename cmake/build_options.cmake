# ============================================================================
#  build_options.cmake — user-facing build switches for rtos_manager.
#
#  Every RTOS_ENABLE_* flag is a plain cache option, so CMakePresets and
#  `-DRTOS_ENABLE_X=ON` on the command line both take effect. Included before
#  compiler_options.cmake, which consumes RTOS_ENABLE_WARNINGS_AS_ERRORS.
# ============================================================================

option(RTOS_ENABLE_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(RTOS_ENABLE_TESTS              "Build unit tests (CTest)"          ON)
option(RTOS_ENABLE_COVERAGE           "Enable gcov/gcovr coverage"        OFF)
option(RTOS_ENABLE_DOCS               "Build Doxygen documentation"       OFF)
option(RTOS_ENABLE_EXAMPLES           "Build examples"                    OFF)
option(RTOS_ENABLE_BENCH              "Build benchmarks"                  OFF)
option(RTOS_ENABLE_PROTOBUF           "Build protobuf/OpenAPI contracts"  OFF)

# --- Default build type -----------------------------------------------------
# Default to Release when no build type is set (single-config generators).
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "No build type specified, defaulting to 'Release'")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
               Debug Release RelWithDebInfo MinSizeRel)
endif()

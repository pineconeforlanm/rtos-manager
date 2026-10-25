# ============================================================================
#  rtos-manager — top-level CMake configuration
#
#  Toolchain: CMake + Conan 2 + GCC/G++ + gcovr + Doxygen + OpenAPI
#  Branch model: Git Flow (see CONTRIBUTING.md)
#
#  This file describes the project only: metadata, the build graph and the two
#  setup/finalize hooks. Options, toolchain policy, dependencies, generated
#  headers, dev tooling and packaging all live under cmake/.
# ============================================================================
cmake_minimum_required(VERSION 3.28)

# ---------------------------------------------------------------------------
# Project metadata (single source of truth for the version).
# Bump these on a release commit; version info is injected into the binary.
# ---------------------------------------------------------------------------
project(
  rtos_manager
  VERSION 0.1.2
  DESCRIPTION "RTOS Manager — an HTTP service for managing RTOS devices"
  HOMEPAGE_URL "https://github.com/pineconeforlanm/rtos-manager"
  LANGUAGES CXX C)

# ---------------------------------------------------------------------------
# Configure-time setup: switches, toolchain policy, generated metadata,
# dependencies and developer tooling (see cmake/project_setup.cmake).
# ---------------------------------------------------------------------------
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/project_setup.cmake)

# ---------------------------------------------------------------------------
# Build graph
# ---------------------------------------------------------------------------
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

# protos/ is reserved for future features — wired lazily so the skeleton
# builds cleanly today.
if(RTOS_ENABLE_PROTOBUF AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/protos/CMakeLists.txt")
  add_subdirectory(protos)
endif()

# ---------------------------------------------------------------------------
# Post-target work: packaging (CPack needs every install() rule above) and the
# configure summary (see cmake/project_finalize.cmake).
# ---------------------------------------------------------------------------
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/project_finalize.cmake)

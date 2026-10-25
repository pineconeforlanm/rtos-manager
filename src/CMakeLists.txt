# ============================================================================
#  src/CMakeLists.txt — build the rtos_manager core library + executable
# ============================================================================

# --- Keep third-party headers out of our -Werror blast radius ----------------
# Imported Conan targets expose their include dirs as normal (non-SYSTEM)
# includes; Glaze / CLI11 headers would then trip our strict warnings. ylt's
# `yalantinglibs` INTERFACE target likewise lists its Asio/cinatra/easylog dirs
# as plain INTERFACE includes. Re-tag them SYSTEM so the compiler silences
# diagnostics coming from those third-party headers.
foreach(_rtos_dep glaze::glaze CLI11::CLI11 yalantinglibs
                  GTest::gtest GTest::gmock GTest::gtest_main
                  benchmark::benchmark benchmark::benchmark_main)
  if(TARGET ${_rtos_dep})
    get_target_property(_rtos_inc ${_rtos_dep} INTERFACE_INCLUDE_DIRECTORIES)
    if(_rtos_inc)
      set_target_properties(${_rtos_dep} PROPERTIES
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${_rtos_inc}")
    endif()
  endif()
endforeach()

# --- Core library (version, config, logging, HTTP server) -------------------
# -Wnull-dereference is a middle-end (optimizer) diagnostic that, unlike
# front-end warnings, is NOT silenced by -isystem. It fires from Asio's
# templated io_context/scheduler code vendored inside yalantinglibs, so relax
# just that warning for the single TU that includes coro_http (per-source
# options are appended after target-level flags, so the -Wno wins).
set_source_files_properties(http_server.cc PROPERTIES
  COMPILE_OPTIONS "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wno-null-dereference>")

add_library(rtos_manager_core STATIC
  version.cc
  cli.cc
  application.cc
  config.cc
  logging.cc
  http_server.cc)
add_library(rtos::core ALIAS rtos_manager_core)

target_include_directories(rtos_manager_core
  PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
    $<BUILD_INTERFACE:${RTOS_GENERATED_INCLUDE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# rtos::ylt is PUBLIC so the coro_http/easylog include dirs reach the executable
# and the tests, which also emit logs / register handlers directly.
# CLI11 stays PRIVATE: it is an implementation detail of cli.cc, invisible to
# anyone consuming CommandLine (see include/rtos_manager/cli.hpp).
target_link_libraries(rtos_manager_core
  PUBLIC
    rtos::ylt
    rtos::project_options
  PRIVATE
    glaze::glaze
    CLI11::CLI11)

rtos_add_default_warnings(rtos_manager_core)

# --- Executable (CLI tool + HTTP service) -----------------------------------
# main.cc only delegates to Application::Run(), so the executable needs nothing
# beyond the core library.
add_executable(rtos_manager main.cc)

target_link_libraries(rtos_manager PRIVATE rtos::core)

rtos_add_default_warnings(rtos_manager)

set_target_properties(rtos_manager PROPERTIES
  OUTPUT_NAME "rtos-manager"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# --- Install ----------------------------------------------------------------
include(GNUInstallDirs)

install(TARGETS rtos_manager_core
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(TARGETS rtos_manager RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/rtos_manager
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
# version.hpp includes the configure-time generated header, and
# RTOS_GENERATED_INCLUDE_DIR is a BUILD_INTERFACE-only include dir — without this
# the installed <rtos_manager/version.hpp> would not compile downstream.
install(FILES ${RTOS_GENERATED_INCLUDE_DIR}/rtos_manager/version_info.hpp
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/rtos_manager)
# Default configuration file (systemd unit references /usr/share/rtos-manager).
install(FILES ${PROJECT_SOURCE_DIR}/config/rtos_manager.yaml
        DESTINATION ${CMAKE_INSTALL_DATADIR}/rtos-manager)

# NOTE: `install(EXPORT)` is intentionally not used yet. rtos_manager_core
# PUBLIC-links rtos::ylt (a vendored INTERFACE target whose headers are
# required by consumers of <rtos_manager/http_server.hpp>), which would force
# us to also export the yalantinglibs INTERFACE target and its transitive
# Threads/dl deps. Defer downstream `find_package(rtos_manager)` support until
# the public surface stabilises; consumers currently add_subdirectory() the
# project or link the installed static lib manually.

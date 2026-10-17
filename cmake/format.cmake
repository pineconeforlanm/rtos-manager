# ============================================================================
#  format.cmake — clang-format / clang-tidy developer conveniences
#
#  Adds custom targets (only when the tools are present):
#    format        -> rewrite sources in-place per .clang-format
#    format-check  -> exit non-zero on any diff (CI gate)
#    tidy          -> run clang-tidy over compile_commands.json
#
#  The toolchain itself is wired through CMakePresets (`tidy` configure preset
#  sets CMAKE_CXX_CLANG_TIDY, so a regular build already runs clang-tidy).
# ============================================================================

set(RTOS_FORMAT_GLOBS
    "include/*.hpp" "include/*.h"
    "src/*.cc"     "src/*.hpp" "src/*.h"
    "test/*.cc"
    "bench/*.cc"
    "example/*.cc")

find_program(CLANG_FORMAT_EXECUTABLE NAMES clang-format clang-format-18 clang-format-17)
find_program(CLANG_TIDY_EXECUTABLE   NAMES clang-tidy   clang-tidy-18   clang-tidy-17)

if(CLANG_FORMAT_EXECUTABLE)
  message(STATUS "clang-format found: ${CLANG_FORMAT_EXECUTABLE}")

  add_custom_target(format
    COMMAND ${CLANG_FORMAT_EXECUTABLE} -i -style=file ${RTOS_FORMAT_GLOBS}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running clang-format -i on project sources"
    VERBATIM)

  add_custom_target(format-check
    COMMAND ${CLANG_FORMAT_EXECUTABLE} --dry-run --Werror
            -style=file ${RTOS_FORMAT_GLOBS}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Checking clang-format compliance (no writes)"
    VERBATIM)
else()
  message(STATUS "clang-format not found — `format` / `format-check` targets unavailable")
endif()

if(CLANG_TIDY_EXECUTABLE)
  message(STATUS "clang-tidy found: ${CLANG_TIDY_EXECUTABLE}")
  # `tidy` target relies on a configured build dir with compile_commands.json.
  add_custom_target(tidy
    COMMAND ${CMAKE_COMMAND} -E echo
            "Running clang-tidy over all translation units in ${CMAKE_BINARY_DIR}"
    COMMAND ${CLANG_TIDY_EXECUTABLE} -p "${CMAKE_BINARY_DIR}"
            "${CMAKE_SOURCE_DIR}/src/version.cc"
            "${CMAKE_SOURCE_DIR}/src/config.cc"
            "${CMAKE_SOURCE_DIR}/src/logging.cc"
            "${CMAKE_SOURCE_DIR}/src/http_server.cc"
            "${CMAKE_SOURCE_DIR}/src/main.cc"
    COMMENT "clang-tidy analysis (use the `tidy` configure preset for full sweep)"
    VERBATIM)
else()
  message(STATUS "clang-tidy not found — `tidy` custom target unavailable "
                 "(the `tidy` configure preset will also fail)")
endif()

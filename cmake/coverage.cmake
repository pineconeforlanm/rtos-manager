# ============================================================================
#  coverage.cmake — gcov/gcovr instrumentation (enabled via RTOS_ENABLE_COVERAGE)
#
#  When ON, every target is compiled with coverage flags and a convenience
#  `coverage` target runs gcovr to produce HTML + XML reports under
#  <build>/coverage/, writes a plain-text table to <build>/coverage/coverage.txt,
#  and prints a coverage summary to the terminal.
# ============================================================================

if(RTOS_ENABLE_COVERAGE)
  if(NOT CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    message(WARNING "RTOS_ENABLE_COVERAGE is only supported with GCC/Clang; ignoring.")
  else()
    message(STATUS "Coverage instrumentation ENABLED (gcov/gcovr)")
    add_compile_options(--coverage -O0 -g -fprofile-arcs -ftest-coverage)
    add_link_options(--coverage)
  endif()
endif()

# --- gcovr report target ----------------------------------------------------
find_program(GCOVR_EXECUTABLE NAMES gcovr)

if(GCOVR_EXECUTABLE AND NOT TARGET coverage)
  set(RTOS_COVERAGE_OUTPUT_DIR "${CMAKE_BINARY_DIR}/coverage"
      CACHE PATH "Where gcovr writes its reports")

  add_custom_target(coverage
    COMMAND ${CMAKE_COMMAND} -E make_directory "${RTOS_COVERAGE_OUTPUT_DIR}"
    COMMAND ${GCOVR_EXECUTABLE}
            --root "${CMAKE_SOURCE_DIR}"
            --filter "${CMAKE_SOURCE_DIR}/src/.*"
            --exclude "${CMAKE_SOURCE_DIR}/test/.*"
            --exclude "${CMAKE_SOURCE_DIR}/thirdparty/.*"
            --html --html-details "${RTOS_COVERAGE_OUTPUT_DIR}/index.html"
            --xml "${RTOS_COVERAGE_OUTPUT_DIR}/coverage.xml"
            --txt "${RTOS_COVERAGE_OUTPUT_DIR}/coverage.txt"
            --print-summary
            --gcov-ignore-parse-errors=negative_hits.warn
            -j 0
    # Echo the full per-file text table to the terminal (gcovr --print-summary
    # only shows the aggregate lines/functions/branches totals).
    COMMAND ${CMAKE_COMMAND} -E cat "${RTOS_COVERAGE_OUTPUT_DIR}/coverage.txt"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    COMMENT "Running gcovr -> ${RTOS_COVERAGE_OUTPUT_DIR}/index.html (+ coverage.txt, summary to terminal)"
    VERBATIM)

  message(STATUS "Coverage target available: `cmake --build <dir> --target coverage`")
endif()

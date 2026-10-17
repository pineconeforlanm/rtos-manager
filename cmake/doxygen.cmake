# ============================================================================
#  doxygen.cmake — Doxygen documentation helper
#
#  Provides rtos_add_documentation(DOXYFILE_IN ... OUTPUT_DIR ... INPUT ...
#  EXTRA_STYLESHEETS ...) which configures a Doxyfile from a template and
#  registers a `docs` target.
# ============================================================================
find_package(Doxygen QUIET)

# Diagrams require Graphviz's `dot`. Enable them only when it is present so
# environments without Graphviz still generate clean docs.
find_program(RTOS_DOT_EXECUTABLE dot)

function(rtos_add_documentation)
  if(NOT DOXYGEN_FOUND)
    message(WARNING "Doxygen not found — documentation target will be skipped")
    return()
  endif()

  cmake_parse_arguments(DOC "" "DOXYFILE_IN;OUTPUT_DIR;INPUT" "EXTRA_STYLESHEETS" ${ARGN})

  if(NOT DOC_DOXYFILE_IN)
    message(FATAL_ERROR "rtos_add_documentation: DOXYFILE_IN is required")
  endif()

  # Doxygen parses INPUT and HTML_EXTRA_STYLESHEET as whitespace-separated
  # lists, so convert CMake's ';' separated lists to spaces.
  string(REPLACE ";" " " DOXYGEN_INPUT "${DOC_INPUT}")
  string(REPLACE ";" " " DOXYGEN_HTML_EXTRA_STYLESHEET "${DOC_EXTRA_STYLESHEETS}")
  set(DOXYGEN_OUTPUT_DIRECTORY "${DOC_OUTPUT_DIR}")
  if(RTOS_DOT_EXECUTABLE)
    set(DOXYGEN_HAVE_DOT "YES")
  else()
    set(DOXYGEN_HAVE_DOT "NO")
  endif()

  set(DOC_OUT "${CMAKE_CURRENT_BINARY_DIR}/Doxyfile")
  configure_file("${DOC_DOXYFILE_IN}" "${DOC_OUT}" @ONLY)

  if(DOC_EXTRA_STYLESHEETS)
    message(STATUS "Doxygen theme stylesheets: ${DOC_EXTRA_STYLESHEETS}")
  endif()

  add_custom_target(docs
    COMMAND ${DOXYGEN_EXECUTABLE} "${DOC_OUT}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    COMMENT "Generating API documentation with Doxygen -> ${DOC_OUTPUT_DIR}"
    VERBATIM)
endfunction()

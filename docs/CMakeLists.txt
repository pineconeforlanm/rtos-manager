# ============================================================================
#  docs/CMakeLists.txt — Doxygen API documentation (RTOS_ENABLE_DOCS=ON)
#
#  The doxygen-awesome-css theme is vendored in-repo under
#  docs/doxygen-awesome/ (MIT licensed), so no network download is required
#  after a fresh clone.
# ============================================================================
include(doxygen)

if(DOXYGEN_FOUND)
  set(_awesome_dir "${CMAKE_CURRENT_SOURCE_DIR}/doxygen-awesome")

  rtos_add_documentation(
    DOXYFILE_IN "${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile.in"
    OUTPUT_DIR  "${CMAKE_BINARY_DIR}"
    INPUT       "${PROJECT_SOURCE_DIR}/include;${PROJECT_SOURCE_DIR}/src"
    EXTRA_STYLESHEETS
      "${_awesome_dir}/doxygen-awesome.css"
      "${_awesome_dir}/doxygen-awesome-sidebar-only.css")

  message(STATUS "Doxygen theme: doxygen-awesome-css (vendored in docs/doxygen-awesome/)")
  message(STATUS "Docs target available: `cmake --build <dir> --target docs` -> ${CMAKE_BINARY_DIR}/html")
else()
  message(STATUS "Doxygen not found — skipping docs target")
endif()

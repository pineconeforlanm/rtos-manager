# ============================================================================
#  summary.cmake — one-shot configure summary.
#
#  Call rtos_print_build_summary() at the very end of the top-level
#  CMakeLists.txt so every reported value is final (all modules included,
#  every option resolved).
# ============================================================================

function(rtos_print_build_summary)
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
endfunction()

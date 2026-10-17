# ============================================================================
#  test/unittest/CMakeLists.txt — unit tests (GoogleTest + CTest)
#
#  Naming convention: every unit-test source uses the `ut_` prefix (integration
#  tests, when added later, use `it_`). Executable targets keep their
#  <subject>_test names, which is also what CTest reports.
# ============================================================================
include(GoogleTest)

# --- version metadata -------------------------------------------------------
add_executable(version_test ut_version.cc)
target_link_libraries(version_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
rtos_add_default_warnings(version_test)
gtest_discover_tests(version_test)

# --- YAML config reflection -------------------------------------------------
add_executable(config_test ut_config.cc)
target_link_libraries(config_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
rtos_add_default_warnings(config_test)
gtest_discover_tests(config_test)

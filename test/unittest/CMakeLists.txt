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

# --- command-line parsing ---------------------------------------------------
add_executable(cli_test ut_cli.cc)
target_link_libraries(cli_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
# CLI11 validates file existence while parsing (CLI::ExistingFile), so the tests
# need a path that really resolves.
target_compile_definitions(cli_test PRIVATE
  "RTOS_TEST_CONFIG_FILE=\"${PROJECT_SOURCE_DIR}/config/rtos_manager.yaml\"")
rtos_add_default_warnings(cli_test)
gtest_discover_tests(cli_test)

# --- YAML config reflection -------------------------------------------------
add_executable(config_test ut_config.cc)
target_link_libraries(config_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
rtos_add_default_warnings(config_test)
gtest_discover_tests(config_test)

# --- logging bootstrap ------------------------------------------------------
add_executable(logging_test ut_logging.cc)
target_link_libraries(logging_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
rtos_add_default_warnings(logging_test)
gtest_discover_tests(logging_test)

# --- startup pipeline -------------------------------------------------------
# The backend is injected, so the whole lifecycle runs without a socket.
add_executable(application_test ut_application.cc)
target_link_libraries(application_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
rtos_add_default_warnings(application_test)
gtest_discover_tests(application_test)

# --- HTTP handler -----------------------------------------------------------
# Same relaxation as src/http_server.cc: Asio's templated io_context code inside
# yalantinglibs trips -Wnull-dereference, which -isystem does not suppress.
set_source_files_properties(ut_http_server.cc PROPERTIES
  COMPILE_OPTIONS "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wno-null-dereference>")

add_executable(http_server_test ut_http_server.cc)
target_link_libraries(http_server_test PRIVATE
  rtos::core
  GTest::gtest
  GTest::gtest_main)
rtos_add_default_warnings(http_server_test)
gtest_discover_tests(http_server_test)

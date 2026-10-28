# ============================================================================
#  dependencies.cmake — third-party packages and vendored sources.
#
#    * Conan provides: glaze (config), CLI11 (cli), gtest/benchmark (test),
#      libpqxx (PostgreSQL client), redis-plus-plus (Redis client).
#    * yalantinglibs (coro_http + easylog) is vendored under thirdparty/ via a
#      git submodule and exposed through the header-only target rtos::ylt.
#
#  Included after compiler_options.cmake (thirdparty links rtos::stdcxx_exp)
#  and before any add_subdirectory() of our own code.
# ============================================================================

find_package(glaze CONFIG REQUIRED)   # YAML/JSON config reflection (glaze::glaze)
find_package(CLI11 CONFIG REQUIRED)   # command-line parsing (CLI11::CLI11)

# Database clients for the Redis + PostgreSQL stack (docker/docker-compose.yml).
# Linked PRIVATE into rtos::core — see src/CMakeLists.txt.
find_package(libpqxx CONFIG REQUIRED) # PostgreSQL C++ client (libpqxx::pqxx)
find_package(redis++ CONFIG REQUIRED) # Redis C++ client (redis++::redis++_static)

if(RTOS_ENABLE_TESTS)
  find_package(GTest CONFIG REQUIRED)     # GTest::gtest / GTest::gtest_main
endif()
if(RTOS_ENABLE_BENCH)
  find_package(benchmark CONFIG REQUIRED) # benchmark::benchmark / benchmark::benchmark_main
endif()

# -> rtos::ylt (coro_http + easylog), header-only.
add_subdirectory(thirdparty)

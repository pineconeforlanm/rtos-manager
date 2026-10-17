# ============================================================================
#  bench/CMakeLists.txt — micro-benchmarks (Google Benchmark, RTOS_ENABLE_BENCH)
#
#  Produces `build/<preset>/bin/rtos_bench`. The strict project warning set is
#  intentionally NOT applied here: the BENCHMARK()/benchmark::State macros and
#  the Glaze/iguana reflection headers are not -Werror-clean.
# ============================================================================
add_executable(rtos_bench bm_serialization.cc)

# rtos::core brings config.hpp + rtos::ylt (struct_json / struct_yaml headers);
# glaze::glaze is PRIVATE to core, so it must be linked here directly.
target_link_libraries(rtos_bench PRIVATE
  rtos::core
  glaze::glaze
  benchmark::benchmark
  benchmark::benchmark_main)

set_target_properties(rtos_bench PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

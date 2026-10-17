# ============================================================================
#  example/CMakeLists.txt — runnable examples (RTOS_ENABLE_EXAMPLES=ON)
#
#  Layout convention (scales to many examples):
#      example/<name>/exp_<name>.cc   ->  target exp_<name>  ->  bin/examples/
#  Both the source file and the produced executable carry the `exp_` prefix so
#  build output is instantly recognisable as an example. Examples are
#  intentionally NOT installed, so they stay out of the .deb.
# ============================================================================

# rtos_add_example(<name>): builds example/<name>/exp_<name>.cc into an
# exp_<name> executable linked against the vendored coro_http stack. Adding a
# new example is one folder + one call below.
function(rtos_add_example name)
  add_executable(exp_${name} "${name}/exp_${name}.cc")
  # rtos::ylt carries libstdc++exp (std::stacktrace runtime for coro_http
  # coroutines) via its INTERFACE, so no per-target link flag is needed here.
  target_link_libraries(exp_${name} PRIVATE rtos::ylt)
  rtos_add_default_warnings(exp_${name})
  set_target_properties(exp_${name} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/examples")
endfunction()

# Standalone coro_http *client* that exercises the running rtos-manager
# service's GET /api/v1/version endpoint.
rtos_add_example(api_client)

# ============================================================================
#  openapi.cmake — validate + render api/openapi.yaml using local tooling.
#
#  Provides three custom targets:
#    openapi-validate : lint the YAML contract (npx @redocly/cli)
#    openapi-docs     : render a single-page HTML to <build>/openapi/index.html
#    openapi          : both (the default workflow hook)
#
#  Strategy: 本机 npm 全局或项目级 cli 优先；否则走 `npx --yes` 临时拉取。
#  CI 跑这个会慢但无需镜像装 node；本地一次安装永久复用。
#
#      npm install -g@redocly/cli
#  or
#      npx --yes @redocly/cli --version
# ============================================================================

set(RTOS_OPENAPI_SPEC "${CMAKE_SOURCE_DIR}/api/openapi.yaml")
set(RTOS_OPENAPI_OUT_DIR "${CMAKE_BINARY_DIR}/openapi")

if(NOT EXISTS "${RTOS_OPENAPI_SPEC}")
  message(STATUS "openapi: spec not present at ${RTOS_OPENAPI_SPEC}, skipping target")
  return()
endif()

find_program(NPX_EXECUTABLE NAMES npx)
if(NOT NPX_EXECUTABLE)
  message(STATUS "openapi: npx not found, targets unavailable "
                 "(install Node.js + npm to enable)")
  return()
endif()

file(MAKE_DIRECTORY "${RTOS_OPENAPI_OUT_DIR}")

add_custom_target(openapi-validate
  COMMAND ${NPX_EXECUTABLE} --yes @redocly/cli@latest lint
          "${RTOS_OPENAPI_SPEC}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Linting api/openapi.yaml via @redocly/cli"
  VERBATIM)

add_custom_target(openapi-docs
  COMMAND ${CMAKE_COMMAND} -E make_directory "${RTOS_OPENAPI_OUT_DIR}"
  COMMAND ${NPX_EXECUTABLE} --yes @redocly/cli@latest build-docs
          "${RTOS_OPENAPI_SPEC}"
          -o "${RTOS_OPENAPI_OUT_DIR}/index.html"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Rendering OpenAPI HTML -> ${RTOS_OPENAPI_OUT_DIR}/index.html"
  VERBATIM)

add_custom_target(openapi
  DEPENDS openapi-validate openapi-docs
  COMMENT "OpenAPI: validate + docs")

message(STATUS "OpenAPI targets available (uses npx @redocly/cli)")
message(STATUS "  cmake --build <dir> --target openapi")
message(STATUS "  spec: ${RTOS_OPENAPI_SPEC}")

# ============================================================================
#  thirdparty/CMakeLists.txt — vendored third-party code
#
#  yalantinglibs (coro_http + easylog) is consumed exactly the way upstream
#  documents (README "CMake add_subdirectory"): add_subdirectory the submodule
#  and link its header-only INTERFACE target `yalantinglibs::yalantinglibs`.
#  That target carries the correct include dirs, Threads/dl and feature
#  defines (YLT_ENABLE_DL, optional SSL/io_uring …) so we stay behaviour-
#  identical to the library's own integration instead of hand-rolling one.
#
#  Two project-specific guards:
#   * EXCLUDE_FROM_ALL — keeps ylt's own tests/examples out of our default
#     build; we only consume the INTERFACE target.
#   * The include dirs are re-tagged SYSTEM in src/CMakeLists.txt so Asio /
#     cinatra / easylog headers stay out of our -Werror blast radius, and the
#     library's install(DIRECTORY include/) rules are filtered out of our DEB.
# ============================================================================

set(_ylt_root "${CMAKE_CURRENT_SOURCE_DIR}/yalantinglibs")

if(NOT EXISTS "${_ylt_root}/include/ylt/coro_http/coro_http_server.hpp")
  message(FATAL_ERROR
    "yalantinglibs submodule missing at thirdparty/yalantinglibs. "
    "Run: git submodule update --init --recursive")
endif()

# Feature selection. ylt's cmake/config.cmake declares each of these via option()
# and consumes the CACHE value, so we must FORCE them BEFORE add_subdirectory().
#   * YLT_ENABLE_SSL  -> HTTPS, pulls OpenSSL (find_package(OpenSSL REQUIRED)).
#   * YLT_ENABLE_IO_URING -> Linux async net I/O (find_package(uring REQUIRED));
#     replaces epoll with io_uring for all sockets.
#   * YLT_ENABLE_STRUCT_PACK_* -> struct_pack serialisation tweaks; header-only
#     compile definitions, no external library.
# NOTE: SSL and io_uring are hard build requirements — configuring without the
# libssl-dev / liburing-dev packages fails. They also become DEB runtime deps
# (see cmake/packaging.cmake CPACK_DEBIAN_PACKAGE_DEPENDS).
option(YLT_ENABLE_SSL "Enable ssl support" ON)
set(YLT_ENABLE_SSL ON CACHE BOOL "" FORCE)

option(YLT_ENABLE_IO_URING "Enable io_uring for all network I/O" ON)
set(YLT_ENABLE_IO_URING ON CACHE BOOL "" FORCE)

option(YLT_ENABLE_STRUCT_PACK_UNPORTABLE_TYPE "struct_pack: allow unportable types (wchar_t)" ON)
set(YLT_ENABLE_STRUCT_PACK_UNPORTABLE_TYPE ON CACHE BOOL "" FORCE)

option(YLT_ENABLE_STRUCT_PACK_OPTIMIZE "struct_pack: optimise (slower compile)" ON)
set(YLT_ENABLE_STRUCT_PACK_OPTIMIZE ON CACHE BOOL "" FORCE)

# Official integration path (header-only INTERFACE target + Threads/dl +
# YLT_ENABLE_DL). EXCLUDE_FROM_ALL: only the target is used, nothing ylt builds.
add_subdirectory("${_ylt_root}" yalantinglibs EXCLUDE_FROM_ALL)

# Namespaced alias so the rest of the project keeps a consistent link name.
add_library(rtos_ylt_alias INTERFACE)
target_link_libraries(rtos_ylt_alias INTERFACE yalantinglibs::yalantinglibs)
# coro_http / async_simple coroutines emit std::stacktrace symbols whose
# out-of-line definitions live in libstdc++exp (see rtos::stdcxx_exp). Attaching
# it to this header-only INTERFACE means every ylt consumer — the core server
# library AND the example HTTP client — inherits the runtime automatically, so
# no individual target repeats the flag.
target_link_libraries(rtos_ylt_alias INTERFACE rtos::stdcxx_exp)
add_library(rtos::ylt ALIAS rtos_ylt_alias)

# ============================================================================
#  compiler_options.cmake — C++ standard, reflection, strict warnings,
#  optimization & hardening policy.
#
#  Included from the top-level CMakeLists.txt. Provides interface targets:
#    * rtos::project_options  -> standard + reflection + optimization + hardening
#    * rtos::warnings         -> strict warning flag set (attach per target)
#  and the helper  rtos_add_default_warnings(<target> ...).
# ============================================================================
include(CheckCXXCompilerFlag)
include(CMakePushCheckState)

# --- Language standard ------------------------------------------------------
# The project owns the C++ standard (default: C++26). Applied as a NORMAL
# variable so a Conan profile's compiler.cppstd cannot silently win.
set(RTOS_CXX_STANDARD 26 CACHE STRING "C++ standard for rtos_manager (17/20/23/26)")
set_property(CACHE RTOS_CXX_STANDARD PROPERTY STRINGS 17 20 23 26)
set(CMAKE_CXX_STANDARD ${RTOS_CXX_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_C_STANDARD 17 CACHE STRING "C standard")
set(CMAKE_C_STANDARD_REQUIRED ON)

# --- Global build behaviour -------------------------------------------------
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

# C++26 makes CMake scan every source for module dependencies (CMP0155). On GCC
# that rewrites the object rule as `-fmodules-ts` + a module mapper, a mode in
# which the per-object depfile is never produced. The consequence is silent and
# expensive: editing a header does NOT rebuild the translation units that
# include it, so an object compiled against an older declaration survives until
# something touches the .cc file. This project uses no C++ modules, so the scan
# buys nothing — keep the plain `-MD` depfile path.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Map our option onto CMake's built-in warning-as-error (>= 3.24).
if(RTOS_ENABLE_WARNINGS_AS_ERRORS)
  set(CMAKE_COMPILE_WARNING_AS_ERROR ON)
endif()

# --- Feature options --------------------------------------------------------
option(RTOS_ENABLE_REFLECTION "Enable C++ reflection (-freflection) + link libstdc++exp" ON)
option(RTOS_ENABLE_HARDENING  "Enable security hardening flags (stack protector, fortify)" ON)
option(RTOS_ENABLE_LTO        "Enable interprocedural optimization (LTO/IPO)" OFF)

# --- Project options interface ----------------------------------------------
add_library(rtos_project_options INTERFACE)
add_library(rtos::project_options ALIAS rtos_project_options)
target_compile_features(rtos_project_options INTERFACE cxx_std_${RTOS_CXX_STANDARD})

# --- libstdc++ experimental runtime (single source of truth) ----------------
# `stdc++exp` carries the out-of-line definitions for two C++ features this
# project relies on:
#   * std::stacktrace, emitted by coro_http / async_simple coroutines
#     (thirdparty ylt), and
#   * the reflection runtime used by -freflection below.
# Exposing it as a named INTERFACE target means every consumer links it exactly
# once via a target (rtos::ylt, rtos::project_options) instead of repeating a
# raw `-lstdc++exp` at each call site. Guarded to libstdc++ >= 13 (GCC 13+),
# where the library exists; on other toolchains the symbols are provided
# elsewhere, so the interface simply carries nothing.
add_library(rtos_stdcxx_exp INTERFACE)
add_library(rtos::stdcxx_exp ALIAS rtos_stdcxx_exp)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND
   CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 13)
  target_link_libraries(rtos_stdcxx_exp INTERFACE stdc++exp)
endif()

# --- Reflection (GCC, experimental C++26) -----------------------------------
if(RTOS_ENABLE_REFLECTION)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_FLAGS "-std=c++${RTOS_CXX_STANDARD}")
    check_cxx_compiler_flag("-freflection" RTOS_COMPILER_HAS_REFLECTION)
    cmake_pop_check_state()

    if(RTOS_COMPILER_HAS_REFLECTION)
      message(STATUS "C++ reflection ENABLED: -freflection, active link of -lstdc++exp")
      target_compile_options(rtos_project_options INTERFACE -freflection)
      # Explicitly link the experimental reflection runtime library (shared
      # target with the coro_http stacktrace dependency — see rtos::stdcxx_exp).
      target_link_libraries(rtos_project_options INTERFACE rtos::stdcxx_exp)
    else()
      message(WARNING "RTOS_ENABLE_REFLECTION=ON but '${CMAKE_CXX_COMPILER_ID}' lacks -freflection; ignoring")
    endif()
  endif()
endif()

# --- Optimization (per build type) ------------------------------------------
# -pipe speeds up compilation; -fno-omit-frame-pointer keeps reliable backtraces;
# Debug uses -Og (debug-friendly optimization); Release/RelWithDebInfo bump -O.
target_compile_options(rtos_project_options INTERFACE
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-pipe;-fno-omit-frame-pointer>
  $<$<CONFIG:Debug>:-Og>
  $<$<CONFIG:Release>:-O3>
  $<$<CONFIG:RelWithDebInfo>:-O2>)

# --- Hardening (non-Debug, GCC/Clang) ---------------------------------------
if(RTOS_ENABLE_HARDENING)
  target_compile_options(rtos_project_options INTERFACE
    $<$<AND:$<NOT:$<CXX_COMPILER_ID:MSVC>>,$<NOT:$<CONFIG:Debug>>>:-fstack-protector-strong>)
  # _FORTIFY_SOURCE requires an optimizing build (-O1+), so skip it for Debug.
  target_compile_definitions(rtos_project_options INTERFACE
    $<$<AND:$<NOT:$<CXX_COMPILER_ID:MSVC>>,$<CONFIG:Release>>:_FORTIFY_SOURCE=2>)
endif()

# --- LTO / IPO --------------------------------------------------------------
if(RTOS_ENABLE_LTO)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT _rtos_ipo_ok OUTPUT _rtos_ipo_msg LANGUAGES CXX)
  if(_rtos_ipo_ok)
    message(STATUS "Interprocedural optimization (LTO) ENABLED")
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
  else()
    message(WARNING "RTOS_ENABLE_LTO=ON but LTO unsupported: ${_rtos_ipo_msg}")
  endif()
endif()

# --- Warning flag sets ------------------------------------------------------
set(_RTOS_WARNINGS_GCC_CLANG_CXX
    -Wall -Wextra -Wpedantic
    -Wshadow
    -Wnon-virtual-dtor
    -Wold-style-cast
    -Wcast-align
    -Wcast-qual
    -Wunused
    -Woverloaded-virtual
    -Wconversion
    -Wsign-conversion
    -Wnull-dereference
    -Wdouble-promotion
    -Wformat=2
    -Wimplicit-fallthrough
    -Wswitch-enum
    -Wundef
    -Wuseless-cast
    -Wzero-as-null-pointer-constant
    -Wpointer-arith
    -Wmissing-declarations
    -Wfloat-equal
    -Wwrite-strings)

set(_RTOS_WARNINGS_GCC_CLANG_C
    -Wall -Wextra -Wpedantic
    -Wshadow
    -Wundef
    -Wpointer-arith
    -Wcast-qual
    -Wwrite-strings)

set(_RTOS_WARNINGS_MSVC /W4 /permissive-)

# Interface library carrying the warnings (propagates via linking).
add_library(rtos_warnings INTERFACE)
add_library(rtos::warnings ALIAS rtos_warnings)
target_compile_options(rtos_warnings INTERFACE
  $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<CXX_COMPILER_ID:GNU,Clang,AppleClang>>:${_RTOS_WARNINGS_GCC_CLANG_CXX}>
  $<$<AND:$<COMPILE_LANGUAGE:C>,$<C_COMPILER_ID:GNU,Clang,AppleClang>>:${_RTOS_WARNINGS_GCC_CLANG_C}>
  $<$<CXX_COMPILER_ID:MSVC>:${_RTOS_WARNINGS_MSVC}>)

# --- Helper -----------------------------------------------------------------
# rtos_add_default_warnings(<target> [<target> ...])
function(rtos_add_default_warnings)
  foreach(_tgt ${ARGN})
    if(TARGET ${_tgt})
      target_link_libraries(${_tgt} PRIVATE rtos::warnings)
    else()
      message(FATAL_ERROR "rtos_add_default_warnings: target '${_tgt}' does not exist")
    endif()
  endforeach()
endfunction()

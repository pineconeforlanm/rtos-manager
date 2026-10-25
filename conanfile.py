"""Conan 2 recipe / dependency manifest for rtos-manager.

Dependencies are resolved automatically at CMake configure time through the
CMake-Conan provider (`conan_provider.cmake`, wired in CMakePresets.json via
CMAKE_PROJECT_TOP_LEVEL_INCLUDES). A plain preset build is enough:

    cmake --preset release
    cmake --build --preset release
    ctest  --preset release

Dependencies (via Conan):
  * cli11      — command-line parsing.
  * glaze      — YAML/JSON config parsing via compile-time reflection.
  * gtest      — unit test framework (RTOS_ENABLE_TESTS).
  * benchmark  — Google Benchmark micro-benchmarks (RTOS_ENABLE_BENCH).
  * openssl    — TLS backend for coro_http (YLT_ENABLE_SSL=ON).
  * liburing   — io_uring network backend for coro_http (YLT_ENABLE_IO_URING=ON).

Note: the HTTP backend (coro_http) and the logging framework (easylog) both
come from yalantinglibs, which is vendored as a git submodule under
thirdparty/yalantinglibs (it is not published on ConanCenter). Boost is no
longer required — coro_http ships its own standalone Asio. ylt's FindOpenSSL /
Finduring modules locate their headers+libs through the paths that the Conan
CMakeToolchain injects, so declaring openssl/liburing here is enough — no
system -dev packages are needed.
"""

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMakeConfigDeps, CMake, cmake_layout


class RtosManagerConan(ConanFile):
    name = "rtos_manager"
    version = "0.1.2"
    description = "RTOS Manager — an HTTP service for managing RTOS devices"
    license = "Apache-2.0"
    url = "https://github.com/pineconeforlanm/rtos-manager"
    settings = "os", "compiler", "build_type", "arch"

    def requirements(self):
        self.requires("cli11/2.7.2")
        self.requires("glaze/8.4.0")
        # TLS + io_uring backends required by ylt when YLT_ENABLE_SSL /
        # YLT_ENABLE_IO_URING are ON (see thirdparty/CMakeLists.txt).
        self.requires("openssl/[>=3 <4]")
        self.requires("liburing/[>=2.3 <3]")
        # Test / benchmark frameworks (gated at the CMake level, always fetched).
        self.requires("gtest/1.18.0")
        self.requires("benchmark/1.9.5")

    def layout(self):
        # Keep the per-config build folders flat (build/<preset>), matching the
        # binaryDir used by CMakePresets.json.
        pass

    def generate(self):
        # Emit the CMake integration files (toolchain + dependency configs) that
        # the conan_provider.cmake picks up automatically at configure time.
        # CMakeConfigDeps is the generator recommended by the CMake-Conan provider.
        deps = CMakeConfigDeps(self)
        deps.generate()

        tc = CMakeToolchain(self)
        # Do not emit a root CMakeUserPresets.json: we ship our own
        # CMakePresets.json, and per-build_type installs would otherwise add
        # duplicate `conan-*` presets that break preset resolution.
        tc.user_presets_path = False
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
        cmake.test()

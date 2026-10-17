# ============================================================================
#  packaging.cmake — systemd unit + CPack packaging (DEB) + maintainer scripts
#
#  Included at the very end of the top-level CMakeLists so install() rules
#  from every sub-directory are already known to CPack. Packaging (and the
#  systemd service) is Linux-only.
#
#  Layout produced inside the .deb (CPACK_PACKAGING_INSTALL_PREFIX = /usr):
#    /usr/bin/rtos-manager
#    /usr/lib/systemd/system/rtos-manager.service
#    /usr/share/rtos-manager/rtos_manager.yaml
#    /etc/version/rtos-manager.version
# ============================================================================
if(NOT UNIX)
  return()
endif()

include(GNUInstallDirs)

# --- systemd unit -----------------------------------------------------------
# Absolute paths baked into the unit match the packaged FHS layout: files are
# rooted at ${RTOS_PACKAGE_PREFIX} inside the .deb (see CPACK_PACKAGING_INSTALL_PREFIX).
set(RTOS_PACKAGE_PREFIX "/usr")
set(RTOS_SERVICE_NAME        "rtos-manager.service")
set(RTOS_SERVICE_BINARY      "${RTOS_PACKAGE_PREFIX}/${CMAKE_INSTALL_BINDIR}/rtos-manager")
set(RTOS_SERVICE_CONFIG      "${RTOS_PACKAGE_PREFIX}/${CMAKE_INSTALL_DATADIR}/rtos-manager/rtos_manager.yaml")

set(_service_in  "${CMAKE_CURRENT_LIST_DIR}/templates/rtos-manager.service.in")
set(_service_out "${CMAKE_CURRENT_BINARY_DIR}/rtos-manager.service")
configure_file("${_service_in}" "${_service_out}" @ONLY)

install(FILES "${_service_out}"
        DESTINATION "lib/systemd/system")

# --- /etc/version/<pkg>.version (运维查看包内版本，与二进制 --version 一致) ----
set(_pkg_version_in  "${CMAKE_CURRENT_LIST_DIR}/templates/rtos-manager.version.in")
set(_pkg_version_out "${CMAKE_CURRENT_BINARY_DIR}/rtos-manager.version")
configure_file("${_pkg_version_in}" "${_pkg_version_out}" @ONLY)
install(FILES "${_pkg_version_out}"
        DESTINATION "etc/version"
        PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)

# --- DEB maintainer scripts (preinst / postinst / prerm / postrm) -----------
# 安装/卸载时自动 systemctl daemon-reload + enable + restart。所有脚本统一引用
# @RTOS_SERVICE_NAME@，避免旧工程里"preinst 用 A 变量、postinst 用 B 变量"导致
# 渲染后服务名为空的 bug。
set(_RTOS_MAINT_SCRIPTS preinst postinst prerm postrm)
set(_RTOS_MAINT_BUILT "")
foreach(_s IN LISTS _RTOS_MAINT_SCRIPTS)
  set(_in  "${CMAKE_CURRENT_LIST_DIR}/templates/maint/${_s}.in")
  set(_out "${CMAKE_CURRENT_BINARY_DIR}/maint/${_s}")
  if(NOT EXISTS "${_in}")
    message(FATAL_ERROR "Missing maintainer script template: ${_in}")
  endif()
  configure_file("${_in}" "${_out}" @ONLY)
  file(CHMOD "${_out}"
       PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                   GROUP_READ GROUP_EXECUTE
                   WORLD_READ  WORLD_EXECUTE)
  list(APPEND _RTOS_MAINT_BUILT "${_out}")
endforeach()

# --- CPack -----------------------------------------------------------------
set(CPACK_GENERATOR "DEB")
set(CPACK_PACKAGE_NAME "rtos-manager")
set(CPACK_PACKAGE_VENDOR "rtos-manager")
set(CPACK_PACKAGE_CONTACT "rtos-manager@localhost")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${PROJECT_VERSION_PATCH}")
if(DEFINED RTOS_VERSION_PRE_RELEASE AND NOT RTOS_VERSION_PRE_RELEASE STREQUAL "")
  # CPack 仅接受 M.N.P 三段，semver 预发布标识落到 package 文件名里。
  set(CPACK_PACKAGE_VERSION_TWEAK "${RTOS_VERSION_PRE_NUM}")
endif()

# 包内文件 FHS 根（注意是 PACKAGING 不是 PACKING，旧名拼错会让 deb 内路径回退到 /usr/local）。
set(CPACK_PACKAGING_INSTALL_PREFIX "${RTOS_PACKAGE_PREFIX}")

# --- artifact file name (build-type aware) ---------------------------------
# Release          : 干净、可对外分发，不带 hash 尾缀
#                    rtos-manager-<semver>-<arch>.deb
# Debug (日常开发)  : 临时部署/调试包——含 build type / 分支 / short hash / dirty
#                    rtos-manager-<semver>-Debug-<branch>-<hash>[-dirty]-<arch>.deb
# 其他(如 RelWithDebInfo): 不带 hash，但标注 build type，避免与 Release 同名冲突。
string(SUBSTRING "${RTOS_GIT_HASH_SHORT}" 0 7 _RTOS_HASH7)
string(TOLOWER "${CMAKE_BUILD_TYPE}" _RTOS_BUILDTYPE_LC)
# 分支名可能含 '/'、空格等，规整为文件名安全字符，并截断到 20 字符防止包名过长。
string(REGEX REPLACE "[^A-Za-z0-9._+-]" "-" _RTOS_PKG_BRANCH "${RTOS_GIT_BRANCH}")
string(SUBSTRING "${_RTOS_PKG_BRANCH}" 0 20 _RTOS_PKG_BRANCH)

if(_RTOS_BUILDTYPE_LC STREQUAL "debug")
  set(CPACK_PACKAGE_FILE_NAME
      "${CPACK_PACKAGE_NAME}-${RTOS_VERSION_SEMVER}-Debug-${_RTOS_PKG_BRANCH}-${_RTOS_HASH7}${RTOS_PACKAGE_DIRTYSUFFIX}-${CMAKE_SYSTEM_PROCESSOR}")
elseif(_RTOS_BUILDTYPE_LC STREQUAL "release")
  set(CPACK_PACKAGE_FILE_NAME
      "${CPACK_PACKAGE_NAME}-${RTOS_VERSION_SEMVER}-${CMAKE_SYSTEM_PROCESSOR}")
else()
  set(CPACK_PACKAGE_FILE_NAME
      "${CPACK_PACKAGE_NAME}-${RTOS_VERSION_SEMVER}-${CMAKE_BUILD_TYPE}-${CMAKE_SYSTEM_PROCESSOR}")
endif()

# Debian 架构映射
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
  set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(armv7l|armhf)$")
  set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "armhf")
else()
  message(WARNING "Unknown CMAKE_SYSTEM_PROCESSOR='${CMAKE_SYSTEM_PROCESSOR}', CPack DEB arch may be wrong")
endif()

set(CPACK_DEBIAN_PACKAGE_SECTION "utils")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "${PROJECT_HOMEPAGE_URL}")
set(CPACK_DEBIAN_PACKAGE_CONTROL_STRICT_PERMISSION ON)
set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA "${_RTOS_MAINT_BUILT}")

# Runtime shared-library dependencies. Auto-detection (dpkg-shlibdeps) is used
# when available; otherwise fall back to a conservative explicit list. The
# coro_http/easylog backend is header-only. Even with YLT_ENABLE_SSL and
# YLT_ENABLE_IO_URING switched ON (see thirdparty/CMakeLists.txt), OpenSSL and
# liburing arrive through Conan as STATIC libraries and are linked directly into
# the binary — ldd shows no libssl/libcrypto/liburing soname deps — so the DEB
# runtime deps stay limited to the C++ runtime, pthreads, libdl and systemd.
# (If the Conan profile is ever switched to shared openssl/liburing, dpkg-shlibdeps
# will pick up the new soname deps automatically; the manual fallback would need
# libssl3 / liburing2 appended there.)
find_program(DPKG_SHLIBDEPS dpkg-shlibdeps)
if(DPKG_SHLIBDEPS)
  set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
else()
  set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6 (>= 2.34), libstdc++6, libgcc-s1, systemd")
endif()

include(CPack)

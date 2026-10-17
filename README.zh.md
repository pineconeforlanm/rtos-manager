<p align="center">
  <h1 align="center">rtos-manager</h1>
  <h6 align="center">一个用于管理 RTOS 设备的 HTTP 服务。</h6>
</p>

<p align="center">
  <img alt="license" src="https://img.shields.io/github/license/pineconeforlanm/rtos-manager?style=flat-square">
  <img alt="language" src="https://img.shields.io/github/languages/top/pineconeforlanm/rtos-manager?style=flat-square">
  <img alt="version" src="https://img.shields.io/badge/version-0.1.0-orange?style=flat-square">
  <img alt="last commit" src="https://img.shields.io/github/last-commit/pineconeforlanm/rtos-manager?style=flat-square">
</p>

`rtos-manager` 是一个 C++ HTTP 服务，未来会成长为完整的设备/运行时管理控制面。
当前仓库是**项目骨架**：一个可构建的最小服务，配备现代化的 CMake + Conan 工具链、
编译期注入二进制的版本/构建元信息、Git Flow 分支模型，以及测试、覆盖率、文档、
API 契约等工程化钩子。

<p align="center">
  <a href="README.md">English README</a>
</p>

---

## 技术栈

| 关注点       | 工具                                              |
|--------------|---------------------------------------------------|
| 构建系统     | [CMake](https://cmake.org/)（≥ 3.28，presets）     |
| 包管理       | [Conan 2](https://conan.io/)                      |
| 编译器       | GCC / G++（C++26，`-freflection`）                |
| 单元测试     | [GoogleTest](https://github.com/google/googletest) + CTest |
| 性能基准     | [Google Benchmark](https://github.com/google/benchmark) |
| 覆盖率       | [gcovr](https://gcovr.com/)                       |
| 文档         | [Doxygen](https://www.doxygen.nl/) + [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css) |
| HTTP 后端    | [coro_http](https://github.com/alibaba/yalantinglibs)（yalantinglibs，header-only） |
| CLI 解析     | [CLI11](https://github.com/CLIUtils/CLI11)        |
| 配置解析     | [glaze](https://github.com/stephenberry/glaze)（YAML，编译期反射） |
| 日志         | [easylog](https://github.com/alibaba/yalantinglibs)（yalantinglibs，header-only） |
| 打包         | [CPack](https://cmake.org/cpack/)（仅 DEB）        |
| 服务管理     | systemd                                           |
| API 契约     | OpenAPI 3.1 + Hoppscotch 集合                     |
| 依赖         | CLI11、glaze、gtest、benchmark（Conan）；yalantinglibs（git 子模块） |

---

## 项目结构

```
rtos-manager/
├── CMakeLists.txt          # 顶层工程与选项
├── CMakePresets.json       # configure/build/test/package/workflow 预设（Conan 感知）
├── conanfile.py            # Conan 2 依赖清单
├── cliff.toml              # git-cliff 配置（从 Conventional Commits 生成 CHANGELOG）
├── cmake/                  # 可复用的 CMake 模块
│   ├── compiler_options.cmake  # C++26 标准、反射、告警、优化
│   ├── version_info.cmake      # Git + semver + 系统/构建元信息 -> version_info.hpp
│   ├── coverage.cmake          # gcov/gcovr 插桩 + `coverage` 目标
│   ├── doxygen.cmake           # `docs` 目标
│   ├── openapi.cmake           # `openapi` 目标（npx @redocly/cli lint + build-docs）
│   ├── format.cmake            # clang-format / clang-tidy 便捷目标
│   ├── changelog.cmake         # git-cliff 生成 CHANGELOG 的 `changelog` 目标
│   ├── packaging.cmake         # systemd unit + CPack DEB + 维护脚本 + 版本文件
│   └── templates/              # 各类 configure_file 模板（#pragma once + 嵌套命名空间）
├── include/rtos_manager/   # 公共头文件（version/config/logging/http_server）
├── src/                    # 核心库 + 可执行文件（CLI 工具 + HTTP 守护进程）
├── test/unittest/          # 单元测试（ut_*.cc，GoogleTest + CTest）
├── example/                # 示例，每个一个子目录（RTOS_ENABLE_EXAMPLES=ON）
│   └── api_client/
│       └── exp_api_client.cc   # coro_http 客户端，访问 GET /api/v1/version
├── bench/                  # Google Benchmark（bm_*.cc，RTOS_ENABLE_BENCH）
├── docs/                   # Doxygen 配置 + 内置 doxygen-awesome 主题
├── api/
│   ├── openapi.yaml                              # OpenAPI 3.1 契约（REST 接口唯一来源）
│   └── rtos-manager.hoppscotch.json          # Hoppscotch 可导入的接口集合
├── config/                 # 运行时配置（YAML）
└── thirdparty/             # 内置依赖：yalantinglibs（coro_http + easylog）
```

---

## 快速开始

### 前置依赖

```bash
pip install conan gcovr            # Conan 2 + gcovr
sudo apt install doxygen ninja-build
sudo apt install graphviz dpkg-dev # 可选：Doxygen 图 / DEB 自动 shlib 依赖
```

> `yalantinglibs`（coro_http + easylog）**不是** Conan 包，而是以 git 子模块
> 内置在 `thirdparty/yalantinglibs`，暴露为 header-only 的 `rtos::ylt` 目标。
> 克隆时带上子模块，或先执行 `git submodule update --init --recursive`。
> Conan 默认 profile 必须使用 `compiler.cppstd=26`（glaze 需要 ≥ 23）。

### 构建与运行

Conan 依赖会在 configure 阶段由 CMake-Conan provider（`conan_provider.cmake`）
**自动拉取**，无需手动 `conan install`，直接选一个 preset：

```bash
cmake --preset release
cmake --build --preset release
ctest  --preset release
./build/release/bin/rtos-manager -h               # 帮助
./build/release/bin/rtos-manager -v               # 打印版本/构建元信息
./build/release/bin/rtos-manager -c config/rtos_manager.yaml   # 启动 HTTP 守护进程
```

> **CLI 只支持三个参数**：`-h`（帮助）、`-v`（版本）、`-c`（配置文件路径）。
> 其余所有运行期配置（监听 host/port、IO 线程数、日志）都写在 YAML 配置文件里。

#### 用 `cmake --workflow` 一键跑完整生命周期

| 工作流       | 做什么                                                       |
|--------------|--------------------------------------------------------------|
| `dev`        | Debug configure + build + test（日常开发循环）               |
| `full`       | 覆盖率 configure + build + test + gcovr 报告                 |
| `release`    | Release configure + build + test + DEB 打包（干净，无 hash）  |
| `package-debug` | Debug configure + build + test + DEB（日常部署/调试，带 hash） |
| `sanitize`   | ASan + UBSan configure + build + test                        |
| `docs`       | Doxygen + OpenAPI 文档渲染                                   |
| `bench`      | 构建 Google Benchmark 可执行文件                             |
| `ci-lint`    | clang-tidy 静态分析                                          |

```bash
cmake --workflow dev            # 本地快速循环
cmake --workflow release        # → build/release/rtos-manager-<ver>-<arch>.deb（干净，无 hash）
cmake --workflow package-debug  # → build/debug/rtos-manager-<ver>-Debug-<branch>-<hash>[-dirty]-<arch>.deb
cmake --workflow full           # 覆盖率 HTML 在 build/coverage/index.html
```

### 示例（RTOS_ENABLE_EXAMPLES=ON，debug 预设默认开启）

示例按“每个一个子目录”组织在 `example/<name>/exp_<name>.cc`，产物位于
`build/<preset>/bin/examples/exp_<name>`（`exp_` 前缀标识示例）。目前只有一个
——一个 coro_http **客户端**，用来验证正在运行的服务：

```bash
# 终端 1：启动服务
./build/debug/bin/rtos-manager -c config/rtos_manager.yaml
# 终端 2：请求 GET /api/v1/version 并打印 JSON
./build/debug/bin/examples/exp_api_client
./build/debug/bin/examples/exp_api_client http://127.0.0.1:8080/api/v1/version
```

### HTTP 接口（RESTful）

MVP 阶段只暴露一个接口：

| 方法 | 路径              | 响应                          |
|------|-------------------|-------------------------------|
| GET  | `/api/v1/version` | JSON 构建元信息（git、build…）|

```bash
curl -s http://127.0.0.1:8080/api/v1/version
```

```json
{
  "project": "rtos_manager",
  "version": "0.1.0",
  "gitHash": "e2bffce...",
  "branch": "develop",
  "dirty": true,
  "prerelease": false,
  "buildType": "Release",
  "system": "Linux",
  "processor": "x86_64",
  "compiler": "GNU 16.2.0",
  "cxxStandard": "26"
}
```

同一请求也打包成了 **Hoppscotch 集合**
[`api/rtos-manager.hoppscotch.json`](api/rtos-manager.hoppscotch.json)
（含 `Accept: application/json` 请求头，以及断言状态码 200、JSON 内容类型、
`project`/`version`/`buildType` 字段的响应测试）。导入方式：Hoppscotch →
集合 → … → 导入/导出 → **Hoppscotch (v1)**。端点默认 `http://127.0.0.1:8080`，
可自行指向你的实例（或换成 `{{baseUrl}}` 的 Hoppscotch 环境变量）。

### 打包（DEB）+ systemd

`cmake/packaging.cmake` 配置了 CPack（仅 DEB）、systemd unit、
`/etc/version/rtos-manager.version` 文件以及四个 DEB 维护脚本
（`preinst`/`postinst`/`prerm`/`postrm`）——安装软件包时会自动 enable + restart 服务：

**产物文件名按构建类型区分**，避免临时调试包与正式发布包混淆（或互相覆盖）：

| 构建 | 命令 | 产物名 |
|------|------|--------|
| Release | `cmake --workflow release` | `rtos-manager-<ver>-<arch>.deb`（干净，**无 hash**） |
| Debug（日常） | `cmake --workflow package-debug` | `rtos-manager-<ver>-Debug-<branch>-<hash>[-dirty]-<arch>.deb` |

```bash
cmake --workflow release            # 或：cmake --workflow package-debug
sudo dpkg -i build/release/rtos-manager-*.deb
systemctl status rtos-manager
```

### 语义化版本

版本从最近的 Git 标签解析，匹配 `v?MAJOR.MINOR.PATCH[-(alpha|beta|rc).N]`；
无标签时回退到 `CMakeLists.txt` 里的 `project(... VERSION 0.1.0)`。解析结果会
编译进二进制，并体现在 DEB 文件名、`/etc/version` 文件以及
`GET /api/v1/version` 的 JSON 响应里。

### OpenAPI 契约

`api/openapi.yaml` 用 OpenAPI 3.1 描述接口，是唯一来源。构建通过本机
`npx @redocly/cli` 提供：

```bash
cmake --build build/debug --target openapi-validate   # 校验 spec
cmake --build build/debug --target openapi-docs       # 渲染 <build>/openapi/index.html
cmake --build build/debug --target openapi            # 两者都做
```

### 变更日志（git-cliff）

`CHANGELOG.md` 由 [git-cliff](https://git-cliff.org) 依据 Conventional Commits
自动生成（配置见 `cliff.toml`）：

```bash
cmake --build build/debug --target changelog            # 重新生成 CHANGELOG.md
cmake --build build/debug --target changelog-unreleased  # 预览未发布变更
```

---

## 代码风格约定

- C++26，头文件统一使用 `#pragma once`（不再用 `#ifndef` 包含守卫）。
- 命名空间使用 C++17 嵌套写法：`namespace rtos_manager::build { ... }`。
- 函数命名遵循 `readability-identifier-naming.FunctionCase: CamelCase`
  （见 `.clang-tidy`），如 `VersionString()` / `LoadConfig()` / `RunHttpServer()`。
- 格式化用 `.clang-format`（Google 基础 + 2 空格缩进 / 120 列 / 左对齐指针）：
  `cmake --build build/debug --target format`，提交前门禁 `format-check`。

---

## 测试与覆盖率

单元测试基于 **GoogleTest**，通过 `gtest_discover_tests` 自动注册进 CTest：

```bash
cmake --workflow full   # configure + build + test + gcovr 报告
```

## 基准测试

微基准基于 **Google Benchmark**，通过 `bench` 预设开启：

```bash
cmake --workflow bench
./build/bench/bin/rtos_bench
# 按组过滤，例如只跑 JSON 基准：
./build/bench/bin/rtos_bench --benchmark_filter=Json
```

### 序列化性能：Glaze vs. ylt struct_json / struct_yaml

`bench/bm_serialization.cc` 用两套序列化栈对同一份 `AppConfig` 做序列化/解析对比。
Glaze 通过 **C++26 标准静态反射**（`std::meta`，P2996——在 GCC 16 上由
`-std=c++26 -freflection` 自动启用）反射聚合体；ylt 的 `struct_json` / `struct_yaml`
（iguana）则用自己的 `YLT_REFL` 宏注册。代表性数据（越小越好，请在本机重跑
`rtos_bench` 复现）：

| 场景        | Glaze     | iguana (ylt) | 胜者         |
|-------------|----------:|-------------:|--------------|
| JSON 序列化 | **35 ns** | 134 ns       | Glaze (~3.8×) |
| JSON 反序列化 | **83 ns** | 165 ns     | Glaze (~2.0×) |
| YAML 序列化 | 90 ns     | **85 ns**    | 基本持平     |
| YAML 反序列化 | 465 ns   | **247 ns**   | iguana (~1.9×) |

**结论：** JSON 上 Glaze 全面领先（其核心优化路径）；YAML 写入两者相当，
而 iguana 解析约快一倍（Glaze 的 YAML reader 相形之下欠成熟）。对本项目的配置
场景两套都绰绰有余；凡涉及 JSON，Glaze 更优。

---

## 参与贡献

本项目遵循 **Git Flow**。分支模型、提交信息规范与发版流程见
[CONTRIBUTING.md](CONTRIBUTING.md)。发布记录遵循
[Keep a Changelog](https://keepachangelog.com/) 与
[语义化版本](https://semver.org/)，由 git-cliff 维护于 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

Apache-2.0，详见 [LICENSE](LICENSE)。

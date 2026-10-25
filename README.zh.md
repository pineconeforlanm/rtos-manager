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
├── CMakeLists.txt          # 只写项目元数据与构建图（无任何策略/工具细节）
├── CMakePresets.json       # configure/build/test/package/workflow 预设（Conan 感知）
├── conanfile.py            # Conan 2 依赖清单
├── cliff.toml              # git-cliff 配置（从 Conventional Commits 生成 CHANGELOG）
├── cmake/                  # 可复用的 CMake 模块
│   ├── project_setup.cmake     # 配置期唯一入口：开关、工具链、依赖、工具目标
│   ├── project_finalize.cmake  # 目标之后的钩子：打包（CPack）+ 汇总
│   ├── build_options.cmake     # RTOS_ENABLE_* 开关 + 默认构建类型
│   ├── compiler_options.cmake  # C++26 标准、反射、告警、优化
│   ├── dependencies.cmake      # Conan 依赖 + 内置 yalantinglibs（rtos::ylt）
│   ├── version_info.cmake      # Git + semver + 系统/构建元信息 -> version_info.hpp
│   ├── compile_commands.cmake  # compile_commands.json + 源码根软链（clangd）
│   ├── coverage.cmake          # gcov/gcovr 插桩 + `coverage` 目标
│   ├── doxygen.cmake           # `docs` 目标
│   ├── openapi.cmake           # `openapi` 目标（npx @redocly/cli lint + build-docs）
│   ├── changelog.cmake         # git-cliff 生成 CHANGELOG 的 `changelog` 目标
│   ├── packaging.cmake         # systemd unit + CPack DEB + 维护脚本 + 版本文件
│   ├── summary.cmake           # configure 汇总输出（rtos_print_build_summary）
│   └── templates/              # 各类 configure_file 模板（#pragma once + 嵌套命名空间）
├── include/rtos_manager/   # 公共头文件（application/cli/version/config/logging/http_server）
├── src/                    # 核心库 + 可执行文件
│   ├── main.cc                 # 进程入口：Application::Run(argc, argv)
│   ├── application.cc          # 启动流水线（请求 → 配置 → 服务）
│   ├── cli.cc                  # 基于 CLI11 的 CommandLine::Parse
│   ├── version.cc              # BuildInfo：JSON / 紧凑单行渲染
│   ├── config.cc               # YAML → AppConfig（glaze 反射）
│   ├── logging.cc              # easylog 初始化
│   └── http_server.cc          # coro_http 服务 + GET /api/v1/version
├── test/unittest/          # 单元测试（ut_*.cc，GoogleTest + CTest）
├── example/                # 示例，每个一个子目录（RTOS_ENABLE_EXAMPLES=ON）
│   └── api_client/
│       └── exp_api_client.cc   # coro_http 客户端，访问 GET /api/v1/version
├── bench/                  # Google Benchmark（bm_*.cc，RTOS_ENABLE_BENCH）
├── docs/                   # Doxygen 配置 + 内置 doxygen-awesome 主题
├── scripts/                # 开发者工具 —— 刻意放在 CMake 之外
│   ├── gate.sh                 # 提交门禁：格式化 + Release 全流程 + 覆盖率 ≥ 90%
│   ├── format.sh               # clang-format 驱动（全仓 / --check / --staged）
│   ├── build.sh                # 单独跑 Release 构建（-Werror + LTO + 测试）
│   ├── lint.sh                 # 基于 compile_commands.json 的 clang-tidy 驱动
│   ├── commit-msg-check.sh     # Conventional Commits 校验
│   └── install-hooks.sh        # 把 .githooks/* 软链进 .git/hooks
├── .githooks/              # 版本化的 git 钩子（pre-commit、commit-msg）
├── .gitmessage             # 提交信息模板（git config commit.template）
├── api/
│   ├── openapi.yaml                              # OpenAPI 3.1 契约（REST 接口唯一来源）
│   └── rtos-manager.hoppscotch.json          # Hoppscotch 可导入的接口集合
├── config/                 # 运行时配置（YAML）
└── thirdparty/             # 内置依赖：yalantinglibs（coro_http + easylog）
```

---

## 分层架构

启动路径是一条单一职责的链：每一层只认识它下面的一层，`main()` 不承载任何逻辑。

```
main()
 └─▶ Application::Run(argc, argv)          生命周期：跑哪些阶段、按什么顺序
      ├─ CommandLine::Parse(argc, argv)    argv  → 请求值对象
      ├─ LoadConfig(path) -> AppConfig     YAML  → 配置（缺省键回落默认值）
      └─ RunHttpServer(server_config)      配置  → 套接字（阻塞运行）
```

| 层 | 类型 | 头文件 | 职责 |
|----|------|--------|------|
| 进程入口 | `main()` | `src/main.cc` | 只有 `return Application::Run(argc, argv);` |
| 生命周期 | `rtos_manager::Application` | `application.hpp` | 阶段顺序、退出码、配置生命周期 |
| 参数解析 | `rtos_manager::CommandLine` | `cli.hpp` | argv → 请求数据；CLI11 只存在于 `cli.cc` |
| 配置 | `rtos_manager::AppConfig` | `config.hpp` | YAML → 配置，缺省键回落默认值 |
| 构建元数据 | `rtos_manager::BuildInfo` | `version.hpp` | 只读访问器 + `ToString()` / `ToJson()` |
| HTTP 接口 | `RunHttpServer()` | `http_server.hpp` | coro_http 服务、`GET /api/v1/version` |

两条规则保证分层不被破坏：

* **不允许向上调用**：`CommandLine` 不读文件，`BuildInfo` 不打日志，`Application`
  不拼元信息文案——谁负责这件事（配置、输出、生命周期）就由谁来做。因此 `--version`
  的输出在 `Application::ShowVersion()` 里，而不是数据类上的某个方法。
* **数据优于过程**：每个阶段都以值的形式返回结果（`CommandLine`、退出码），
  而不是改全局状态，因此每一层都能单独测试——见 `test/unittest/ut_cli.cc`。

---

## 快速开始

### 前置依赖

```bash
pip install conan gcovr            # Conan 2 + gcovr
sudo apt install doxygen ninja-build
# 代码格式化：scripts/format.sh 与 pre-commit 钩子都依赖它
# （pip --user 会装到 ~/.local/bin；PEP 668 发行版需加
#  --break-system-packages，或改用 apt install clang-format）
pip install --user clang-format
# 可选：scripts/lint.sh 用的 clang-tidy、Doxygen 图用的 graphviz、
# DEB 自动 shlib 依赖用的 dpkg-dev
sudo apt install clang-tidy graphviz dpkg-dev
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

> 格式化**不是** CMake 目标——它由 [`scripts/format.sh`](scripts/format.sh) 承担。
> 把“格式化 + Release 全流程 + 覆盖率全流程”编排在一起的是
> [`scripts/gate.sh`](scripts/gate.sh)，pre-commit 钩子直接调用它，详见
> [开发者工具](#开发者工具)。

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
编译进二进制（通过 `rtos_manager::BuildInfo` 访问，数据源自生成的 `constexpr`
聚合 `rtos_manager::build::kMetadata`），并体现在 DEB 文件名、`/etc/version`
文件以及 `GET /api/v1/version` 的 JSON 响应里。

DEB 控制字段 `Version:` 同样取自标签，但预发布标识写作 `~` 而不是 `-`：
`v0.1.2-rc.1` → 文件名 `rtos-manager-0.1.2-rc.1-x86_64.deb`、控制版本
`0.1.2~rc.1`。这不是美化：dpkg 把**最后一个** `-` 之后看作 Debian 修订号，
字面的 `0.1.2-rc.1` 会排在 `0.1.2` **之后**，正式版将永远覆盖不了自己的候选版。

正式发版前先用 `-rc.N` 演练一遍，步骤与产物/版本映射见
[CONTRIBUTING.md](CONTRIBUTING.md#release-candidates-rcn)。RC 同样是发布物：标签打在
`main` 的发布合并提交上，在 `CHANGELOG.md` 里各自成段（`cliff.toml` 有意让
`vX.Y.Z-rc.N` 命中 `tag_pattern`），且**一旦推送就不再重打/移动/删除**。

### OpenAPI 契约

`api/openapi.yaml` 用 OpenAPI 3.1 描述接口，是唯一来源。构建通过本机
`npx @redocly/cli` 提供：

```bash
cmake --build build/debug --target openapi-validate   # 校验 spec
cmake --build build/debug --target openapi-docs       # 渲染 <build>/openapi/index.html
cmake --build build/debug --target openapi            # 两者都做
```

### 变更日志（git-cliff）

`CHANGELOG.md` 是**生成骨架 + 人工润色**：[git-cliff](https://git-cliff.org) 把上一个
标签以来的 Conventional Commits 归纳成待发布版本的那一节（配置见 `cliff.toml`），
发版提交再把它改写成可读说明。不要整体重生成——`-o CHANGELOG.md` 会把历史中手写的
段落全部替换成机器骨架：

```bash
cmake --build build/debug --target changelog-unreleased  # 只输出待发布版本的那一节
cmake --build build/debug --target changelog             # 整体重生成（破坏性，仅用于重建）
```

---

## 代码风格约定

- C++26，头文件统一使用 `#pragma once`（不再用 `#ifndef` 包含守卫）。
- 命名空间使用 C++17 嵌套写法：`namespace rtos_manager::build { ... }`。
- 函数命名遵循 `readability-identifier-naming.FunctionCase: CamelCase`
  （见 `.clang-tidy`），如 `BuildInfo::ToJson()` / `LoadConfig()` / `RunHttpServer()`。
- 返回类型后置：自由函数与方法统一写 `auto name(args) -> R`；局部变量在类型不改变语义时用
  `auto`（如 `auto text = info.ToString();`）。
- 格式化由 `.clang-format` 定义（Google 基础 + 2 空格缩进 / 120 列 / 左对齐指针），
  通过 `scripts/format.sh` 执行，见下节。

### 开发者工具

格式化、静态检查与提交信息规则都在 [`scripts/`](scripts/) 与
[`.githooks/`](.githooks/) 里，**不在** CMake 构建图中：这些是每个开发者本地的关注点，
不应拖慢或阻塞一次普通的 `cmake --build`。

```bash
scripts/install-hooks.sh                   # 每个 clone 执行一次：软链 .githooks/* 到 .git/hooks
scripts/install-hooks.sh --with-template   # 同时设置 commit.template = .gitmessage

scripts/gate.sh                            # 提交门禁：格式化 + Release + 覆盖率
scripts/gate.sh --skip-coverage            # 本地快速循环时跳过覆盖率
scripts/gate.sh --min-coverage 95          # 单次提高到 95% 门槛

scripts/format.sh                          # 就地重排全部源码
scripts/format.sh --check                  # 门禁：有未格式化文件即非零退出
scripts/format.sh --staged                 # 只处理暂存区文件（钩子会两遍都跑）

scripts/build.sh                           # 单独跑 Release 构建：-Werror + LTO + 测试
scripts/build.sh --test                    # 再跑一遍该 preset 的 ctest
scripts/build.sh --staged                  # 暂存内容与构建无关时自动跳过

scripts/lint.sh                            # clang-tidy 检查 src/*.cc（需已 configure）
scripts/lint.sh --staged --fix             # 只处理暂存文件，并应用建议修复

scripts/commit-msg-check.sh -m "feat(http): add /healthz"   # 提交前先试消息格式
```

| 钩子 | 做什么 | 跳过方式 |
|------|--------|---------|
| `pre-commit` | 执行 `scripts/gate.sh`：对**全仓**做格式化（暂存文件重新 `git add`，未暂存文件只改工作区；若某个暂存文件同时还有未暂存改动则拒绝），随后跑 Release 全流程与覆盖率全流程并卡 90% 阈值 | `git commit --no-verify` |
| `commit-msg` | 拒绝 git-cliff 无法归类的消息（`type` 不合法、缺 `(scope):`、超过 72 字符、结尾句号、正文与标题之间没有空行） | `git commit --no-verify` |

门禁在提交前证明两条完整流水线是绿的：

1. **Release** —— `cmake --workflow release`：configure、以“警告即错误 + LTO”编译
   （比 Debug 严格）、跑完整测试、产出 `.deb`。`-Werror` 回归、漏掉的 include、
   写坏的 preset 都进不了 `develop`。
2. **覆盖率** —— `cmake --workflow full`：插桩构建、同一套测试、gcovr 报告，
   然后由 `gate.sh` 读取 `coverage.xml`，**行覆盖率低于 90% 直接拒绝提交**
   （失败时打印逐文件表格）。

代价：两段都是 `cmake --workflow`，所以每次都会先 configure；而 configure 会重写
`version_info.hpp`（里面嵌了构建时间），因此即便没有任何改动，也会有十几个翻译单元
加一次 LTO 链接被重做。热态下每次提交约一分钟；克隆后第一次提交要跑两遍全量编译，
以分钟计。

`RTOS_GATE_FORMAT=0`、`RTOS_GATE_RELEASE=0`、`RTOS_GATE_COVERAGE=0` 可按次跳过某一段，
`RTOS_GATE_MIN_COVERAGE=95` 可提高门槛，`RTOS_PRECOMMIT_LINT=1` 追加对暂存翻译单元的
clang-tidy。tidy 默认关闭：它要重新解析每个文件，属于 PR 阶段的检查——请用
`scripts/lint.sh` 或 `cmake --workflow ci-lint`。

不使用 `cpplint` 的原因：它固化的是 *Google* 风格（2 空格缩进、80 列、`.cc`/`.h` 成对），
与本项目的 `.clang-format` 冲突；它不认识 C++26 语法；而 `clang-tidy` 已经在真实 AST 上
覆盖了它那些有用的检查（`google-*`、`readability-*`）。多引入一个工具只会多一堆误报，
以及第二个风格真相来源。

`wip:` / `fixup!` / `squash!` / `amend!` 消息会被放行（本地开发需要），但按
[CONTRIBUTING.md](CONTRIBUTING.md) 的要求，开 PR 前必须 squash 成规范的提交。

---

## 测试与覆盖率

单元测试基于 **GoogleTest**，通过 `gtest_discover_tests` 自动注册进 CTest：

```bash
cmake --workflow full   # configure + build + test + gcovr 报告
```

为了让整套测试不依赖端口、线程与 sleep，代码里留了两个接缝：`Application::Run()`
把服务器后端作为参数接收（`Application::ServerRunner`，默认就是真实的
`RunHttpServer`），`/api/v1/version` 的处理器抽成了具名函数 `HandleVersionRequest`，
可以直接喂一个 `coro_http_response` 断言状态码与 JSON 正文。因此启动流程、配置叠加、
日志级别与 HTTP 载荷都能在单测里覆盖。

覆盖率统计范围是 `src/`，但**排除 `src/main.cc`**（见 `cmake/coverage.cmake`）：
`main()` 是进程入口，靠“运行二进制”来覆盖而不是单测，计入统计只会让数字变成
argv 管道的说明。`scripts/gate.sh` 在行覆盖率低于 **90%** 时拒绝提交；逐文件明细在
`build/coverage/coverage/coverage.txt`。

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

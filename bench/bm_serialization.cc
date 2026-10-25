// ============================================================================
//  bm_serialization.cc — Glaze vs. ylt struct_json / struct_yaml
//
//  Measures the two serialisation stacks the project could use for its
//  configuration objects, on the SAME data (rtos_manager::AppConfig):
//
//    * JSON  : glz::write_json / read_json   vs   iguana::to_json / from_json
//    * YAML  : glz::write_yaml / read_yaml   vs   iguana::to_yaml / from_yaml
//
//  (iguana is what <ylt/struct_json/…> and <ylt/struct_yaml/…> alias: the
//  header-only backend vendored inside yalantinglibs.)
//
//  Asymmetric reflection (intentional — this is what each library actually
//  does here, not an apples-to-apples macro-vs-macro test):
//    * Glaze uses C++26 standard static reflection (P2996 std::meta::*, via
//      the `^^T` reflection operator). It is picked automatically because the
//      project compiles with `-std=c++26 -freflection`, under which GCC 16
//      defines __cpp_impl_reflection and Glaze's feature_test.hpp sets
//      GLZ_REFLECTION26=1. No glz::meta specialisation or macro is needed.
//    * iguana (struct_json / struct_yaml) does NOT use std::meta; it relies on
//      its own YLT_REFL registration, done in the rtos_manager namespace below.
//
//  Build with RTOS_ENABLE_BENCH=ON (the `bench` workflow / preset) and run:
//      ./build/bench/bin/rtos_bench
//      ./build/bench/bin/rtos_bench --benchmark_format=json
// ============================================================================
#include <benchmark/benchmark.h>
#include <ylt/struct_json/json_reader.h>
#include <ylt/struct_json/json_writer.h>
#include <ylt/struct_yaml/yaml_reader.h>
#include <ylt/struct_yaml/yaml_writer.h>

#include <glaze/glaze.hpp>
#include <glaze/yaml.hpp>
#include <string>

#include "rtos_manager/config.hpp"

// --- iguana reflection registration ----------------------------------------
// struct_json / struct_yaml resolve member names through YLT_REFL-generated
// refl_visit_members found by ADL, so the registrations live in the same
// namespace as the types. Glaze needs no such macro: it reflects these
// aggregates via C++26 P2996 std::meta (see the file header).
namespace rtos_manager {
YLT_REFL(ServerConfig, host, port, io_threads);
YLT_REFL(LogConfig, level, file, max_size, max_files, console);
YLT_REFL(AppConfig, server, logging);
}  // namespace rtos_manager

namespace {

// A representative, fully-populated configuration used by every benchmark.
rtos_manager::AppConfig MakeFixture() {
  rtos_manager::AppConfig cfg{};
  cfg.server.host = "0.0.0.0";
  cfg.server.port = 8080;
  cfg.server.io_threads = 4;
  cfg.logging.level = "info";
  cfg.logging.file = "logs/rtos-manager.log";
  cfg.logging.max_size = 10485760;
  cfg.logging.max_files = 5;
  cfg.logging.console = true;
  return cfg;
}

// Each engine parses a document produced by *itself*, so the benchmark never
// depends on cross-library format compatibility. Documents are built once.
const std::string& GlazeJsonDoc() {
  static const std::string doc = [] {
    std::string s;
    glz::write_json(MakeFixture(), s);
    return s;
  }();
  return doc;
}
const std::string& GlazeYamlDoc() {
  static const std::string doc = [] {
    std::string s;
    glz::write_yaml(MakeFixture(), s);
    return s;
  }();
  return doc;
}
const std::string& IguanaJsonDoc() {
  static const std::string doc = [] {
    std::string s;
    iguana::to_json(MakeFixture(), s);
    return s;
  }();
  return doc;
}
const std::string& IguanaYamlDoc() {
  static const std::string doc = [] {
    std::string s;
    iguana::to_yaml(MakeFixture(), s);
    return s;
  }();
  return doc;
}

}  // namespace

// --- JSON -------------------------------------------------------------------
static void Glaze_Json_Serialize(benchmark::State& state) {
  const auto cfg = MakeFixture();
  for (auto _ : state) {
    std::string out;
    const auto ec = glz::write_json(cfg, out);
    benchmark::DoNotOptimize(ec);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Glaze_Json_Serialize);

static void Glaze_Json_Deserialize(benchmark::State& state) {
  const std::string& doc = GlazeJsonDoc();
  for (auto _ : state) {
    rtos_manager::AppConfig cfg{};
    const auto ec = glz::read_json(cfg, doc);
    benchmark::DoNotOptimize(ec);
    benchmark::DoNotOptimize(cfg.server.port);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Glaze_Json_Deserialize);

static void Iguana_Json_Serialize(benchmark::State& state) {
  const auto cfg = MakeFixture();
  for (auto _ : state) {
    std::string out;
    iguana::to_json(cfg, out);
    benchmark::DoNotOptimize(out);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Iguana_Json_Serialize);

static void Iguana_Json_Deserialize(benchmark::State& state) {
  const std::string& doc = IguanaJsonDoc();
  for (auto _ : state) {
    rtos_manager::AppConfig cfg{};
    iguana::from_json(cfg, doc);
    benchmark::DoNotOptimize(cfg.server.port);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Iguana_Json_Deserialize);

// --- YAML -------------------------------------------------------------------
static void Glaze_Yaml_Serialize(benchmark::State& state) {
  const auto cfg = MakeFixture();
  for (auto _ : state) {
    std::string out;
    const auto ec = glz::write_yaml(cfg, out);
    benchmark::DoNotOptimize(ec);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Glaze_Yaml_Serialize);

static void Glaze_Yaml_Deserialize(benchmark::State& state) {
  const std::string& doc = GlazeYamlDoc();
  for (auto _ : state) {
    rtos_manager::AppConfig cfg{};
    const auto ec = glz::read_yaml(cfg, doc);
    benchmark::DoNotOptimize(ec);
    benchmark::DoNotOptimize(cfg.server.port);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Glaze_Yaml_Deserialize);

static void Iguana_Yaml_Serialize(benchmark::State& state) {
  const auto cfg = MakeFixture();
  for (auto _ : state) {
    std::string out;
    iguana::to_yaml(cfg, out);
    benchmark::DoNotOptimize(out);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Iguana_Yaml_Serialize);

static void Iguana_Yaml_Deserialize(benchmark::State& state) {
  const std::string& doc = IguanaYamlDoc();
  for (auto _ : state) {
    rtos_manager::AppConfig cfg{};
    iguana::from_yaml(cfg, doc);
    benchmark::DoNotOptimize(cfg.server.port);
    benchmark::ClobberMemory();
  }
}
BENCHMARK(Iguana_Yaml_Deserialize);

// No main(): provided by benchmark::benchmark_main.

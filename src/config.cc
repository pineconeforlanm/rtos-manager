// ============================================================================
//  config.cc — Glaze-based YAML configuration loading.
// ============================================================================
#include "rtos_manager/config.hpp"

#include <format>
#include <fstream>
#include <glaze/glaze.hpp>
#include <glaze/yaml/read.hpp>
#include <sstream>
#include <stdexcept>

namespace rtos_manager {

auto LoadConfig(const std::string& path) -> AppConfig {
  auto in = std::ifstream(path, std::ios::binary);
  if (!in) {
    throw std::runtime_error(std::format("cannot open configuration file: '{}'", path));
  }

  auto ss = std::ostringstream{};
  ss << in.rdbuf();
  const auto text = ss.str();

  auto cfg = AppConfig{};
  if (const auto ec = glz::read_yaml(cfg, text)) {
    throw std::runtime_error(std::format("failed to parse configuration '{}': {}", path, glz::format_error(ec, text)));
  }
  return cfg;
}

}  // namespace rtos_manager

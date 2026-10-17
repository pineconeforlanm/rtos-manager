// ============================================================================
//  config.cc — Glaze-based YAML configuration loading.
// ============================================================================
#include "rtos_manager/config.hpp"

#include <fstream>
#include <format>
#include <sstream>
#include <stdexcept>

#include <glaze/glaze.hpp>
#include <glaze/yaml/read.hpp>

namespace rtos_manager {

AppConfig LoadConfig(const std::string& path) {
  std::ifstream in(path, std::ios::binary);
  if (!in) {
    throw std::runtime_error(std::format("cannot open configuration file: '{}'", path));
  }

  std::ostringstream ss;
  ss << in.rdbuf();
  const std::string text = ss.str();

  AppConfig cfg{};
  if (const auto ec = glz::read_yaml(cfg, text)) {
    throw std::runtime_error(
        std::format("failed to parse configuration '{}': {}", path, glz::format_error(ec, text)));
  }
  return cfg;
}

}  // namespace rtos_manager

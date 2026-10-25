// ============================================================================
//  exp_api_client.cc — a minimal coro_http client that exercises rtos-manager.
//
//  Hits the single MVP endpoint (GET /api/v1/version) and prints the status
//  line + JSON body. Use it to smoke-test a running server:
//
//      # terminal 1 — start the service
//      ./build/release/bin/rtos-manager -c config/rtos_manager.yaml
//
//      # terminal 2 — run this client (optionally point at another host:port)
//      ./build/debug/bin/examples/rtos_api_client
//      ./build/debug/bin/examples/rtos_api_client http://127.0.0.1:8080/api/v1/version
//
//  Built only when RTOS_ENABLE_EXAMPLES=ON; CI compiles but does not run it.
// ============================================================================
#include <cstdio>
#include <string>
#include <ylt/coro_http/coro_http_client.hpp>

namespace {

constexpr const char* kDefaultUrl = "http://127.0.0.1:8080/api/v1/version";

}  // namespace

int main(int argc, char** argv) {
  const std::string url = (argc > 1) ? argv[1] : kDefaultUrl;
  std::printf("GET %s\n", url.c_str());

  coro_http::coro_http_client client{};
  const auto resp = async_simple::coro::syncAwait(client.async_get(url));

  if (resp.net_err) {
    std::fprintf(stderr, "request failed: %s\n", resp.net_err.message().c_str());
    std::fprintf(stderr, "is rtos-manager running? start it with: rtos-manager -c config/rtos_manager.yaml\n");
    return 1;
  }

  std::printf("status : %d\n", resp.status);
  std::printf("body   : %s\n", std::string(resp.resp_body).c_str());
  return resp.status == 200 ? 0 : 1;
}

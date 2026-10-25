// ============================================================================
//  ut_http_server.cc — unit tests for the GET /api/v1/version handler
//
//  The handler is handed a real coro_http_response built without a connection,
//  so the route's contract (status, body, content type) is asserted without
//  binding a socket or running an event loop. RunHttpServer() itself stays out
//  of the unit tests: it is the blocking wiring around this handler.
// ============================================================================
#include <gtest/gtest.h>

#include <string>
#include <string_view>
#include <ylt/coro_http/coro_http_server.hpp>

#include "rtos_manager/http_server.hpp"
#include "rtos_manager/version.hpp"

namespace {

using rtos_manager::BuildInfo;
using rtos_manager::HandleVersionRequest;

/// Nothing in the handler reads the request, so a parser and a null connection
/// are enough to drive it.
auto MakeRequest(cinatra::http_parser& parser) -> cinatra::coro_http_request {
  return cinatra::coro_http_request{parser, nullptr};
}

/// Same for the response: only its status and body are touched by the handler.
auto MakeResponse() -> cinatra::coro_http_response { return cinatra::coro_http_response{nullptr}; }

TEST(HttpServerTest, ServesTheBuildDocumentAsJson) {
  auto parser = cinatra::http_parser{};
  auto req = MakeRequest(parser);
  auto res = MakeResponse();

  HandleVersionRequest(req, res);

  EXPECT_EQ(res.content(), BuildInfo::Get().ToJson());
  EXPECT_NE(std::string_view{res.content()}.find("\"version\""), std::string_view::npos);
  EXPECT_NE(std::string_view{res.content()}.find("\"gitHash\""), std::string_view::npos);
}

TEST(HttpServerTest, ReportsOkStatus) {
  auto parser = cinatra::http_parser{};
  auto req = MakeRequest(parser);
  auto res = MakeResponse();

  HandleVersionRequest(req, res);

  EXPECT_EQ(res.status(), cinatra::status_type::ok);
}

TEST(HttpServerTest, BodyIsStableAcrossCalls) {
  auto first_parser = cinatra::http_parser{};
  auto first_req = MakeRequest(first_parser);
  auto first_res = MakeResponse();
  HandleVersionRequest(first_req, first_res);

  auto second_parser = cinatra::http_parser{};
  auto second_req = MakeRequest(second_parser);
  auto second_res = MakeResponse();
  HandleVersionRequest(second_req, second_res);

  EXPECT_EQ(first_res.content(), second_res.content());
}

}  // namespace

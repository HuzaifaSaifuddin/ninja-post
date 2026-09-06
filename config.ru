# frozen_string_literal: true

# =============================================================================
# config.ru — the rackup entrypoint
# =============================================================================
# This file is evaluated inside a `Rack::Builder` instance (by `rackup`, or by
# `puma config.ru`). Builder gives this file three extra methods:
#
#   use MiddlewareClass, *args   -> wrap the app in an outer layer
#   run app                      -> the final app; requests end up here
#   map "/prefix" do ... end     -> mount a sub-app under a path prefix
#
# Whatever `run` receives must respond to #call(env) and return
# [status, headers, body]. That's the entire contract.
#
# Boot it with:   bundle exec rackup -s puma -p 9292
# or:             bundle exec puma -p 9292 config.ru
# =============================================================================

require "rack"   # rackup only loads rack/builder; we want Rack::Request / Rack::Response
require "json"

# -----------------------------------------------------------------------------
# Middleware: a demonstration of the "wrapping" half of Rack.
# A middleware is ANY object initialized with the next app, exposing #call(env).
# It may inspect/modify env on the way in, and inspect/modify the triple on the
# way out. Our real app will use a couple of these (error handling, logging).
# -----------------------------------------------------------------------------
class RequestTimer
  def initialize(app)
    @app = app
  end

  def call(env)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)           # <- call inward
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
    headers["x-runtime-ms"] = elapsed_ms.to_s        # <- decorate the response
    warn "[RequestTimer] #{env['REQUEST_METHOD']} #{env['PATH_INFO']} -> #{status} (#{elapsed_ms}ms)"
    [status, headers, body]
  end
end

# -----------------------------------------------------------------------------
# The app: boot the full stack (DB + models + actions + router), then declare
# routes. `config/boot.rb` is the single load path every entrypoint shares.
# -----------------------------------------------------------------------------
require_relative "config/boot"

router = NinjaPost::Router.new

router.get("/health") { |_req, _p| NinjaPost::JSONResponse.render(200, status: "ok") }

router.post("/posts") do |req, _params|
  body = NinjaPost::JSONResponse.parse_body(req)

  result = NinjaPost::Actions::CreatePost.call(
    login:   body["login"],
    ip:      body["ip"] || req.ip,   # explicit IP if given, else the socket's
    title:   body["title"],
    content: body["content"]
  )

  NinjaPost::JSONResponse.render(result.status, result.body)
rescue JSON::ParserError
  NinjaPost::JSONResponse.render(400, error: "invalid_json")
end

router.post("/posts/:id/ratings") do |req, params|
  body = NinjaPost::JSONResponse.parse_body(req)

  result = NinjaPost::Actions::RatePost.call(
    post_id: params["id"],
    value:   body["value"]
  )

  NinjaPost::JSONResponse.render(result.status, result.body)
rescue JSON::ParserError
  NinjaPost::JSONResponse.render(400, error: "invalid_json")
end

# -----------------------------------------------------------------------------
# Assemble the stack. Order matters: the FIRST `use` is the OUTERMOST layer.
#   request  -> RequestTimer -> router
#   response <- RequestTimer <- router
# -----------------------------------------------------------------------------
use RequestTimer
run router

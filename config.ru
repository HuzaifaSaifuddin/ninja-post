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
# The app itself. Still a stub — a hand-rolled router replaces this next step.
# Uses Rack::Request / Rack::Response so you can see the ergonomic layer.
# -----------------------------------------------------------------------------
app = lambda do |env|
  req = Rack::Request.new(env)
  res = Rack::Response.new

  res.set_header("content-type", "application/json")

  payload =
    case [req.request_method, req.path_info]
    in ["GET", "/health"]
      { service: "ninja-post", status: "ok" }
    in ["POST", "/echo"]
      raw = req.body.read
      { received: (JSON.parse(raw) rescue raw), ip: req.ip }
    else
      res.status = 404
      { error: "not_found", path: req.path_info }
    end

  res.write(JSON.generate(payload))
  res.finish   # => [status, headers, body]  — the triple Puma wants
end

# -----------------------------------------------------------------------------
# Assemble the stack. Order matters: the FIRST `use` is the OUTERMOST layer.
#   request  -> RequestTimer -> app
#   response <- RequestTimer <- app
# -----------------------------------------------------------------------------
use RequestTimer
run app

# frozen_string_literal: true

# =============================================================================
# 03 — The `rackup` / config.ru / middleware layer
# =============================================================================
# Run:  bundle exec ruby scratch/03_rackup_layer.rb
#
# `config.ru` is NOT magic. It is plain Ruby `instance_eval`'d inside a
# Rack::Builder. That is the only thing `rackup` adds over "call an app object".
# This script reproduces what rackup does, in memory, so you can see:
#   1. how `use` / `run` / `map` build the final app
#   2. middleware ordering (first `use` = outermost)
#   3. that the result is just another call(env) -> triple object
# =============================================================================

require "rack"
require "json"

def section(t) = puts("\n=== #{t} ===")

# ---------------------------------------------------------------------------
# Two demo middlewares. A middleware is: new(next_app) + call(env).
# ---------------------------------------------------------------------------
class Trace
  def initialize(app, label:)
    @app = app
    @label = label
  end

  def call(env)
    (env["trace"] ||= []) << "#{@label}:in"
    status, headers, body = @app.call(env)
    env["trace"] << "#{@label}:out"
    headers["x-trace"] = env["trace"].join(" > ")
    [status, headers, body]
  end
end

class JSONErrors
  def initialize(app) = (@app = app)

  def call(env)
    @app.call(env)
  rescue => e
    [500, { "content-type" => "application/json" },
     [JSON.generate(error: e.class.name, message: e.message)]]
  end
end

# ---------------------------------------------------------------------------
# 1. What `rackup` effectively does: Rack::Builder.new { <contents of config.ru> }
# ---------------------------------------------------------------------------
section "Build a stack the way config.ru would"

built = Rack::Builder.new do
  use JSONErrors                       # outermost: catches everything below
  use Trace, label: "A"                # middle
  use Trace, label: "B"                # innermost middleware

  # `map` mounts a sub-app under a path prefix (SCRIPT_NAME/PATH_INFO split).
  map "/health" do
    run ->(_e) { [200, { "content-type" => "application/json" }, ['{"status":"ok"}']] }
  end

  map "/boom" do
    run ->(_e) { raise "kaboom" }
  end

  # fallthrough app for every other path
  run ->(e) { [404, { "content-type" => "application/json" },
               [JSON.generate(error: "not_found", path: e["PATH_INFO"])]] }
end.to_app

puts "built.class = #{built.class}   (still just a call(env) object)"

# ---------------------------------------------------------------------------
# 2. Drive it with Rack::MockRequest — no server, no port.
# ---------------------------------------------------------------------------
mock = Rack::MockRequest.new(built)

section "GET /health"
r = mock.get("/health")
puts "status  : #{r.status}"
puts "x-trace : #{r.headers['x-trace']}"     # B is innermost -> B:in last, B:out first
puts "body    : #{r.body}"

section "GET /nope (fallthrough 404)"
r = mock.get("/nope")
puts "status: #{r.status}  body: #{r.body}"

section "GET /boom (exception caught by JSONErrors middleware)"
r = mock.get("/boom")
puts "status: #{r.status}  body: #{r.body}"
puts "x-trace present? #{r.headers.key?('x-trace')}  <- no: error short-circuited above Trace"

# ---------------------------------------------------------------------------
# 3. Ordering rule, stated plainly.
# ---------------------------------------------------------------------------
section "Ordering"
puts <<~TXT
  use JSONErrors   <- 1st use  = OUTERMOST (sees request first, response last)
  use Trace A
  use Trace B      <- last use = INNERMOST (closest to `run` app)
  run <app>

  request  : JSONErrors -> A -> B -> app
  response : JSONErrors <- A <- B <- app

  So put cross-cutting concerns (error handling, request-id, logging) FIRST.
TXT

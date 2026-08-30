# frozen_string_literal: true

# =============================================================================
# 01 — The `rack` GEM as a pure library (no server, no socket, no port)
# =============================================================================
# Run:  bundle exec ruby scratch/01_rack_lib.rb
#
# Purpose: show what the `rack` gem gives you on the APP side. None of this
# opens a network connection. `rack` here is just classes that:
#   - read a raw `env` hash ergonomically   -> Rack::Request
#   - build a [status, headers, body] triple -> Rack::Response
#   - fabricate an `env` hash for tests      -> Rack::MockRequest
#   - compose middleware                     -> Rack::Builder
# =============================================================================

require "rack"
require "json"

def section(title) = puts("\n=== #{title} ===")

# -----------------------------------------------------------------------------
# 1. Rack::MockRequest — build an `env` hash without a server.
#    This is exactly how rack-test drives specs later: no puma, no port.
# -----------------------------------------------------------------------------
section "Rack::MockRequest.env_for"
env = Rack::MockRequest.env_for(
  "/posts/42?sort=rating&sort=title",
  method: "POST",
  "CONTENT_TYPE" => "application/json",
  input: JSON.generate(title: "Hello", content: "World", login: "huzaifa"),
  "HTTP_X_FORWARDED_FOR" => "203.0.113.9, 10.0.0.1"
)
puts "class: #{env.class}"
puts "keys : #{env.keys.sort.grep(/\A[A-Z]/).join(', ')}"

# -----------------------------------------------------------------------------
# 2. Rack::Request — the ergonomic read layer over that env hash.
# -----------------------------------------------------------------------------
section "Rack::Request accessors"
req = Rack::Request.new(env)
puts "request_method : #{req.request_method}"
puts "post?          : #{req.post?}"
puts "path_info      : #{req.path_info}"
puts "query_string   : #{req.query_string}"
puts "GET (parsed)   : #{req.GET.inspect}"          # last value wins; use sort[]= for arrays
puts "media_type     : #{req.media_type.inspect}"   # 'application/json' (no charset)
puts "content_length : #{req.content_length.inspect}"
puts "ip             : #{req.ip.inspect}"           # walks X-Forwarded-For!
puts "body.read      : #{req.body.read.inspect}"

# NOTE: req.POST parses ONLY form/multipart bodies, NOT JSON. For a JSON API
# you read req.body and JSON.parse yourself:
req.body.rewind
parsed = JSON.parse(req.body.read)
puts "parsed JSON    : #{parsed.inspect}"

# -----------------------------------------------------------------------------
# 3. Rack::Response — the ergonomic write layer that produces the triple.
# -----------------------------------------------------------------------------
section "Rack::Response builder"
res = Rack::Response.new
res.status = 201
res.set_header("content-type", "application/json")
res.set_header("location", "/posts/42")
res.write(JSON.generate(id: 42, **parsed))
triple = res.finish
puts "status  : #{triple[0]}"
puts "headers : #{triple[1].inspect}"
print "body    : "; triple[2].each { |c| print c }; puts

# -----------------------------------------------------------------------------
# 4. A Rack app is just call(env) -> triple. Call it directly, no server.
# -----------------------------------------------------------------------------
section "Calling an app object directly"
app = lambda do |e|
  r = Rack::Request.new(e)
  [200, { "content-type" => "text/plain" }, ["Hi from #{r.request_method} #{r.path}"]]
end
status, headers, body = app.call(Rack::MockRequest.env_for("/ping"))
puts "#{status} #{headers.inspect} #{body.join}"

# -----------------------------------------------------------------------------
# 5. Rack::Builder — the same object `config.ru` is evaluated in.
#    Middleware = an object initialized with the next app, exposing call(env).
# -----------------------------------------------------------------------------
section "Rack::Builder + middleware, in memory"

class TagHeader
  def initialize(app, name:, value:)
    @app = app
    @name = name
    @value = value
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers[@name] = @value
    [status, headers, body]
  end
end

stacked = Rack::Builder.new do
  use TagHeader, name: "x-app", value: "ninja-post"
  use TagHeader, name: "x-layer", value: "outer-wins-first"
  run ->(_e) { [200, { "content-type" => "text/plain" }, ["stacked"]] }
end.to_app

st, hd, bd = stacked.call(Rack::MockRequest.env_for("/"))
puts "#{st} #{hd.inspect} #{bd.join}"

# -----------------------------------------------------------------------------
# 6. Rack::MockRequest wrapper — call an app the "HTTP verb" way, still no socket.
# -----------------------------------------------------------------------------
section "Rack::MockRequest as a client"
mock = Rack::MockRequest.new(stacked)
resp = mock.get("/anything")
puts "status : #{resp.status}"
puts "headers: #{resp.headers.inspect}"
puts "body   : #{resp.body.inspect}"

puts "\n(Every line above ran with ZERO network I/O — that is the point of the rack gem.)"

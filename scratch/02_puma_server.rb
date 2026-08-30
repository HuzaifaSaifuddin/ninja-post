# frozen_string_literal: true

# =============================================================================
# 02 — PUMA as a bare HTTP server (no rack gem, no rackup, no config.ru)
# =============================================================================
# Run:     bundle exec ruby scratch/02_puma_server.rb
# Probe:   curl -s localhost:9292/health
#          curl -s -X POST localhost:9292/echo -H 'content-type: application/json' -d '{"a":1}'
#          curl -s localhost:9292/slow        # 1s handler, fire several in parallel
#          curl -s localhost:9292/threads
#
# Purpose: show exactly what an HTTP server does and does NOT do for you:
#   DOES : socket, HTTP parse -> env hash, triple -> HTTP bytes, thread pool
#   NOT  : parse query strings / JSON bodies, build responses, routing
# We deliberately never `require "rack"` here.
# =============================================================================

require "puma"
require "json"

STDOUT.sync = true

# A tiny helper so handlers can return a Ruby hash and we JSON-encode once.
def json(status, hash, extra_headers = {})
  [status, { "content-type" => "application/json" }.merge(extra_headers),
   [JSON.generate(hash)]]
end

# ---------------------------------------------------------------------------
# The app. Pure env-hash reading — this is the "no rack gem" experience.
# ---------------------------------------------------------------------------
APP = lambda do |env|
  method = env["REQUEST_METHOD"]
  path   = env["PATH_INFO"]

  case [method, path]
  in ["GET", "/health"]
    json 200, { status: "ok", pid: Process.pid, thread: Thread.current.object_id }

  in ["GET", "/env"]
    # Everything the server handed us, minus unserializable objects.
    dump = env.reject { |_k, v| v.is_a?(IO) || v.respond_to?(:call) || v.is_a?(StringIO) }
    json 200, dump

  in ["POST", "/echo"]
    raw = env["rack.input"].read                       # body is an IO in env
    ct  = env["CONTENT_TYPE"].to_s
    parsed = (JSON.parse(raw) if ct.include?("json") && !raw.empty?)
    json 200, { content_type: ct, raw: raw, parsed: parsed }

  in ["GET", "/query"]
    # The server gives you QUERY_STRING as a raw string. Parsing is YOUR job.
    require "uri"
    json 200, { raw: env["QUERY_STRING"], parsed: URI.decode_www_form(env["QUERY_STRING"].to_s).to_h }

  in ["GET", "/slow"]
    sleep 1                                             # hold the thread 1 second
    json 200, { done: true, thread: Thread.current.object_id }

  in ["GET", "/threads"]
    # Prove Puma runs handlers concurrently: this counter races unless guarded.
    $unsafe ||= 0
    before = $unsafe
    sleep 0.05                        # widen the race window
    $unsafe = before + 1
    json 200, { unsafe_counter: $unsafe, note: "hit this in parallel and watch it under-count" }

  else
    json 404, { error: "not_found", method:, path: }
  end
end

# ---------------------------------------------------------------------------
# Boot Puma directly. No Rack::Handler, no rackup.
# min/max threads control the pool that runs APP.call concurrently.
# ---------------------------------------------------------------------------
server = Puma::Server.new(APP)
server.min_threads = 1
server.max_threads = 8
server.add_tcp_listener("127.0.0.1", 9292)

puts "Puma #{Puma::Const::PUMA_VERSION} on http://127.0.0.1:9292  (pid #{Process.pid}, up to 8 threads)"
puts "Try:  curl -s localhost:9292/health"
puts "      seq 10 | xargs -P10 -I_ curl -s localhost:9292/threads   # see the race"
trap("INT") { server.stop(true); exit }
server.run
sleep

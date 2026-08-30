# frozen_string_literal: true

source "https://rubygems.org"

ruby "~> 3.3"

# --- HTTP layer -------------------------------------------------------------
# The Rack contract + helper classes (Rack::Request, Rack::Response, middleware).
gem "rack", "~> 3.1"
# The conventional, server-agnostic CLI that reads config.ru and boots a server.
# Hard-depends on `rack` (uses Rack::Builder to evaluate config.ru).
gem "rackup", "~> 2.2"
# Threaded application server. Turns HTTP bytes <-> Rack env/triple, runs the
# app in a thread pool.
gem "puma", "~> 6.4"

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

# --- Database ------------------------------------------------------------------
# Sequel: a database toolkit + ORM. NOT ActiveRecord, NOT Rails. Gives us
# migrations, a query DSL, and (importantly for the perf requirements) easy,
# safe raw SQL. Thread-safe connection pool out of the box — matters under Puma.
gem "sequel", "~> 5.80"
# pg: the C driver for PostgreSQL. Sequel talks to Postgres through this.
gem "pg", "~> 1.5"

# --- Development / test tooling ----------------------------------------------
group :development, :test do
  # Random but plausible text for db/seeds.rb (post titles, comment bodies).
  # Not in the :default group, so boot.rb won't auto-require it — seeds.rb
  # requires "faker" explicitly and it never loads in the web/worker process.
  gem "faker", "~> 3.4"
end

group :test do
  # Minitest ships with Ruby; pinned here so `bundle exec` uses a known
  # version rather than whatever the interpreter bundles.
  gem "minitest", "~> 5.22"
  # Drives fake HTTP requests against the Rack app (get/post + last_response).
  gem "rack-test", "~> 2.1"
end

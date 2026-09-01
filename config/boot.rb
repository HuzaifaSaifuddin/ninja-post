# frozen_string_literal: true

# The one file every entrypoint loads: web server, specs, seeds, worker, console.
# Sets up gems + load path + database + application code, in that order.

require "bundler/setup"      # activate exactly the gems in Gemfile.lock
Bundler.require(:default)    # require the default group (rack, puma, sequel, pg...)

APP_ROOT = File.expand_path("..", __dir__)

# Make lib/ requirable without relative paths: require "ninja_post/..."
$LOAD_PATH.unshift File.join(APP_ROOT, "lib")

# Database connection (defines NinjaPost::Database and top-level DB).
require_relative "database"
NinjaPost::Database.connect!

# Application code. Order matters where there are dependencies; for now just
# load everything under lib/ninja_post alphabetically.
Dir[File.join(APP_ROOT, "lib", "ninja_post", "**", "*.rb")].sort.each do |file|
  require file
end

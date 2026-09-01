# frozen_string_literal: true

require "sequel"
require "uri"

# Central database connection for the whole service.
#
# Environment is chosen by APP_ENV (development | test | production),
# defaulting to "development". Each environment gets its own database:
#   ninja_post_development / ninja_post_test / ...
#
# A full DATABASE_URL always wins if provided (useful for CI / production).
module NinjaPost
  module Database
    ENVIRONMENT = (ENV["APP_ENV"] || "development").freeze

    DEFAULTS = {
      # host/port left nil -> local unix socket, current OS user, no password
      max_connections: Integer(ENV.fetch("DB_POOL", "8")),
      # keep timestamps as Ruby Time in local zone; good enough for this service
      timezone: :local,
      # log slow queries while developing; silence in test
      sql_log_level: :debug,
    }.freeze

    module_function

    def url
      ENV["DATABASE_URL"] || "postgres:///ninja_post_#{ENVIRONMENT}"
    end

    # Admin connection to the "postgres" maintenance DB — for CREATE/DROP DATABASE.
    def admin_url
      base = URI.parse(url)
      base.path = "/postgres"
      base.to_s
    end

    def connect!
      return DB if defined?(DB) && DB

      db = Sequel.connect(url, DEFAULTS.dup)
      db.extension :pg_array          # native Postgres arrays (used later for IP -> logins)
      db.pool.connection_validation_timeout = -1 if ENVIRONMENT == "test"

      # Expose as NinjaPost::Database::DB and, for convenience, top-level DB.
      const_set(:DB, db)
      Object.const_set(:DB, db) unless Object.const_defined?(:DB)
      db
    end

    def disconnect!
      return unless defined?(DB) && DB

      DB.disconnect
    end
  end
end

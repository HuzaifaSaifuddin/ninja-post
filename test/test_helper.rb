# frozen_string_literal: true

ENV["APP_ENV"] ||= "test"

require_relative "../config/boot"
require "minitest/autorun"
require "rack/test"

module NinjaPost
  # Base for tests that only touch the DB through the app. Each test runs
  # inside a transaction that is always rolled back, so tests never see each
  # other's writes and the seeded data is left alone. An action's own
  # DB.transaction nests as a savepoint (auto_savepoint: true).
  class Test < Minitest::Test
    include Rack::Test::Methods

    def app = NinjaPost::App.build

    def run
      result = nil
      DB.transaction(rollback: :always, auto_savepoint: true, savepoint: true) do
        result = super
      end
      result
    end

    private

    def post_json(path, payload)
      post(path, JSON.generate(payload), "CONTENT_TYPE" => "application/json")
    end

    def body = JSON.parse(last_response.body)
  end

  # Base for tests that need COMMITTED data visible to other DB connections
  # (the rating-concurrency test spawns threads). No wrapping transaction;
  # instead it cleans the tables it dirties, before and after.
  class IntegrationTest < Minitest::Test
    include Rack::Test::Methods

    TABLES = %i[ratings feedbacks ip_authors posts users].freeze

    def app = NinjaPost::App.build

    def setup    = truncate!
    def teardown = truncate!

    private

    def truncate!
      DB.run("TRUNCATE #{TABLES.join(', ')} RESTART IDENTITY CASCADE")
    end

    def post_json(path, payload)
      post(path, JSON.generate(payload), "CONTENT_TYPE" => "application/json")
    end

    def body = JSON.parse(last_response.body)
  end
end

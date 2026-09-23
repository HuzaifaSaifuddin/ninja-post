# frozen_string_literal: true

require_relative "test_helper"

class HealthTest < NinjaPost::Test
  def test_health_ok
    get "/health"
    assert_equal 200, last_response.status
    assert_equal({ "status" => "ok" }, body)
  end
end

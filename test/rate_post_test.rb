# frozen_string_literal: true

require_relative "test_helper"

class RatePostTest < NinjaPost::Test
  def setup
    post_json "/posts", login: "rater", title: "t", content: "c"
    @post_id = body["id"]
  end

  def test_first_rating_sets_the_average
    post_json "/posts/#{@post_id}/ratings", value: 5
    assert_equal 200, last_response.status
    assert_equal 5.0, body["rating_average"]
  end

  def test_second_rating_moves_the_average
    post_json "/posts/#{@post_id}/ratings", value: 5
    post_json "/posts/#{@post_id}/ratings", value: 2
    assert_equal 3.5, body["rating_average"]
  end

  def test_rejects_value_zero
    post_json "/posts/#{@post_id}/ratings", value: 0
    assert_equal 422, last_response.status
    assert body["errors"].key?("value")
    assert_equal "must be an integer between 1 and 5", body.dig("errors", "value", 0)
  end

  def test_rejects_value_above_five
    post_json "/posts/#{@post_id}/ratings", value: 9
    assert_equal 422, last_response.status
    assert body["errors"].key?("value")
    assert_equal "must be an integer between 1 and 5", body.dig("errors", "value", 0)
  end

  def test_rejects_string_value
    post_json "/posts/#{@post_id}/ratings", value: "2"
    assert_equal 422, last_response.status
    assert body["errors"].key?("value")
    assert_equal "must be an integer between 1 and 5", body.dig("errors", "value", 0)
  end

  def test_rejects_float_value
    post_json "/posts/#{@post_id}/ratings", value: 4.5
    assert_equal 422, last_response.status
    assert body["errors"].key?("value")
    assert_equal "must be an integer between 1 and 5", body.dig("errors", "value", 0)
  end

  def test_rejects_unknown_post_id
    post_json "/posts/#{@post_id + 999_999}/ratings", value: 3
    assert_equal 404, last_response.status
    assert_equal "post_not_found", body["error"]
  end
end

class RatePostConcurrencyTest < NinjaPost::IntegrationTest
  def test_concurrent_ratings_are_not_lost
    post_json "/posts", login: "rater", title: "t", content: "c"
    post_id = body["id"]

    threads = 50.times.map do
      Thread.new do
        # each thread needs its own app instance's underlying connection;
        # Rack::Test::Methods state isn't thread-safe to share, so build fresh
        Rack::Test::Session.new(Rack::MockSession.new(NinjaPost::App.build))
                           .post("/posts/#{post_id}/ratings", JSON.generate(value: 3),
                                 "CONTENT_TYPE" => "application/json")
      end
    end
    threads.each(&:join)

    row = DB[:posts].where(id: post_id).first
    assert_equal 50, row[:rating_count]
    assert_equal 150, row[:rating_sum]
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class TopPostsTest < NinjaPost::Test
  def rate(post_id, value)
    post_json "/posts/#{post_id}/ratings", value: value
  end

  def test_orders_by_average_rating_descending
    post_json "/posts", login: "a", title: "low", content: "x"
    low_id = body["id"]
    rate(low_id, 2)

    post_json "/posts", login: "b", title: "high", content: "x"
    high_id = body["id"]
    rate(high_id, 5)

    get "/posts/top?n=2"
    headings = body.map { |post| post["heading"] }

    assert_equal ["high", "low"], headings
  end

  def test_excludes_unrated_posts
    post_json "/posts", login: "a", title: "rated", content: "x"
    rate(body["id"], 5)

    post_json "/posts", login: "b", title: "never rated", content: "x"

    get "/posts/top?n=10"
    headings = body.map { |post| post["heading"] }

    assert_includes headings, "rated"
    refute_includes headings, "never rated"
  end

  def test_response_shape
    post_json "/posts", login: "a", title: "shaped", content: "body text"
    rate(body["id"], 4)

    get "/posts/top?n=1"

    assert_equal [{ "heading" => "shaped", "content" => "body text" }], body
  end

  def test_limits_to_n
    3.times do |i|
      post_json "/posts", login: "user#{i}", title: "t#{i}", content: "x"
      rate(body["id"], 3)
    end

    get "/posts/top?n=2"

    assert_equal 2, body.length
  end

  def test_defaults_to_ten_when_n_is_missing
    12.times do |i|
      post_json "/posts", login: "user#{i}", title: "t#{i}", content: "x"
      rate(body["id"], 3)
    end

    get "/posts/top"

    assert_equal 10, body.length
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class AddFeedbackTest < NinjaPost::Test
  def setup
    post_json "/posts", login: "owner", title: "t", content: "x"
    @owner_id = body["user_id"]

    post_json "/posts", login: "author", title: "target post", content: "x"
    @post_id = body["id"]
    @post_author_id = body["user_id"]
  end

  def test_adds_feedback_on_a_post
    post_json "/feedbacks", owner_id: @owner_id, post_id: @post_id, comment: "nice"

    assert_equal 200, last_response.status
    feedback = body["feedbacks"].first
    assert_equal "post", feedback["feedback_type"]
    assert_equal @post_id, feedback["post_id"]
  end

  def test_adds_feedback_on_a_user
    post_json "/feedbacks", owner_id: @owner_id, user_id: @post_author_id, comment: "nice person"

    assert_equal 200, last_response.status
    feedback = body["feedbacks"].first
    assert_equal "user", feedback["feedback_type"]
    assert_equal @post_author_id, feedback["user_id"]
  end

  def test_duplicate_feedback_on_same_target_is_a_no_op
    post_json "/feedbacks", owner_id: @owner_id, post_id: @post_id, comment: "first"
    post_json "/feedbacks", owner_id: @owner_id, post_id: @post_id, comment: "second"

    assert_equal 200, last_response.status
    assert_equal 1, body["feedbacks"].length
    assert_equal "first", body["feedbacks"].first["comment"]
  end

  def test_returns_full_feedback_list_for_owner
    post_json "/feedbacks", owner_id: @owner_id, post_id: @post_id, comment: "on the post"
    post_json "/feedbacks", owner_id: @owner_id, user_id: @post_author_id, comment: "on the user"

    assert_equal 2, body["feedbacks"].length
  end

  def test_rejects_missing_target
    post_json "/feedbacks", owner_id: @owner_id, comment: "no target"

    assert_equal 422, last_response.status
    assert body["errors"].key?("target")
  end

  def test_rejects_both_targets
    post_json "/feedbacks", owner_id: @owner_id, post_id: @post_id, user_id: @post_author_id, comment: "x"

    assert_equal 422, last_response.status
    assert body["errors"].key?("target")
  end

  def test_rejects_blank_comment
    post_json "/feedbacks", owner_id: @owner_id, post_id: @post_id, comment: ""

    assert_equal 422, last_response.status
    assert body["errors"].key?("comment")
  end

  def test_rejects_unknown_owner
    post_json "/feedbacks", owner_id: 999_999, post_id: @post_id, comment: "x"

    assert_equal 422, last_response.status
    assert body["errors"].key?("target")
  end

  def test_rejects_unknown_target_post
    post_json "/feedbacks", owner_id: @owner_id, post_id: 999_999, comment: "x"

    assert_equal 422, last_response.status
    assert body["errors"].key?("target")
  end
end

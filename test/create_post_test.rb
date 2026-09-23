# frozen_string_literal: true

require_relative "test_helper"

class CreatePostTest < NinjaPost::Test
  def test_creates_post_and_new_user
    post_json "/posts", login: "dana", title: "hello", content: "world"

    assert_equal 200, last_response.status
    assert_equal "hello", body["title"]
    assert DB[:users].where(login: "dana").any?
  end

  def test_reuses_existing_user
    post_json "/posts", login: "dana", title: "first", content: "one"
    first_user_id = DB[:users].where(login: "dana").get(:id)

    post_json "/posts", login: "dana", title: "second", content: "two"

    assert_equal 200, last_response.status
    assert_equal first_user_id, body["user_id"]
    assert_equal 1, DB[:users].where(login: "dana").count
  end

  def test_rejects_blank_title_and_content
    post_json "/posts", login: "dana", title: "", content: ""

    assert_equal 422, last_response.status
    assert body["errors"].key?("title")
    assert body["errors"].key?("content")
  end

  def test_rejects_missing_login
    post_json "/posts", title: "hello", content: "world"

    assert_equal 422, last_response.status
    assert body["errors"].key?("login")
  end
end

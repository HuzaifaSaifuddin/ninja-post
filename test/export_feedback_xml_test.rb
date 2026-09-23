# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "rexml/document"

class ExportFeedbackXmlTest < NinjaPost::Test
  def setup
    @dir = Dir.mktmpdir("feedback_export_test")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def create_post_feedback
    post_json "/posts", login: "owner", title: "t", content: "x"
    owner_id = body["user_id"]

    post_json "/posts", login: "author", title: "target", content: "x"
    post_id = body["id"]
    post_json "/posts/#{post_id}/ratings", value: 4

    post_json "/feedbacks", owner_id: owner_id, post_id: post_id, comment: "great"
  end

  def create_user_feedback
    post_json "/posts", login: "owner2", title: "t", content: "x"
    owner_id = body["user_id"]

    post_json "/posts", login: "target_user", title: "t2", content: "x"
    target_user_id = body["user_id"]

    post_json "/feedbacks", owner_id: owner_id, user_id: target_user_id, comment: "nice"
  end

  def exported_entries
    path = NinjaPost::Actions::ExportFeedbackXml.call(dir: @dir)
    doc = REXML::Document.new(File.read(path))
    doc.root.elements.to_a("feedback").map do |el|
      {
        owner_login: el.elements["owner_login"].text,
        comment: el.elements["comment"].text,
        rating: el.elements["rating"].text,
        feedback_type: el.elements["feedback_type"].text
      }
    end
  end

  def test_exports_post_feedback_with_rating
    create_post_feedback

    entry = exported_entries.find { |e| e[:feedback_type] == "post" }
    assert_equal "great", entry[:comment]
    assert_equal "4.0", entry[:rating]
  end

  def test_exports_user_feedback_with_empty_rating
    create_user_feedback

    entry = exported_entries.find { |e| e[:feedback_type] == "user" }
    assert_equal "nice", entry[:comment]
    assert_nil entry[:rating]
  end

  def test_exports_one_entry_per_feedback
    create_post_feedback
    create_user_feedback

    assert_equal 2, exported_entries.length
  end
end

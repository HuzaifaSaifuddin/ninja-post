# frozen_string_literal: true

require_relative "test_helper"

class SharedIpsTest < NinjaPost::Test
  def test_lists_ip_with_two_or_more_authors
    post_json "/posts", login: "alice", title: "t", content: "x", ip: "1.2.3.4"
    post_json "/posts", login: "bob", title: "t", content: "x", ip: "1.2.3.4"

    get "/ips"

    assert_includes body, { "ip" => "1.2.3.4", "authors" => ["alice", "bob"] }
  end

  def test_excludes_ip_with_a_single_author
    post_json "/posts", login: "carol", title: "t", content: "x", ip: "9.9.9.9"

    get "/ips"

    refute_includes body.map { |row| row["ip"] }, "9.9.9.9"
  end

  def test_same_author_posting_twice_counts_as_one_author
    post_json "/posts", login: "dana", title: "t1", content: "x", ip: "5.5.5.5"
    post_json "/posts", login: "dana", title: "t2", content: "x", ip: "5.5.5.5"

    get "/ips"

    refute_includes body.map { |row| row["ip"] }, "5.5.5.5"
  end

  def test_authors_are_sorted_alphabetically
    post_json "/posts", login: "zack", title: "t", content: "x", ip: "7.7.7.7"
    post_json "/posts", login: "amy", title: "t", content: "x", ip: "7.7.7.7"

    get "/ips"

    row = body.find { |r| r["ip"] == "7.7.7.7" }
    assert_equal ["amy", "zack"], row["authors"]
  end
end

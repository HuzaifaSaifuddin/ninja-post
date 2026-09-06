# frozen_string_literal: true

require "ninja_post/router"
require "ninja_post/json_response"

module NinjaPost
  # Builds the configured Router (the Rack app). Called by config.ru for the
  # server and by spec_helper for tests — same routes both places.
  module App
    module_function

    def build
      router = Router.new

      router.get("/health") { |_req, _p| JSONResponse.render(200, status: "ok") }

      router.post("/posts") do |req, _params|
        body = JSONResponse.parse_body(req)
        result = Actions::CreatePost.call(
          login:   body["login"],
          ip:      body["ip"] || req.ip,
          title:   body["title"],
          content: body["content"]
        )
        JSONResponse.render(result.status, result.body)
      rescue JSON::ParserError
        JSONResponse.render(400, error: "invalid_json")
      end

      router.post("/posts/:id/ratings") do |req, params|
        body = JSONResponse.parse_body(req)
        result = Actions::RatePost.call(post_id: params["id"], value: body["value"])
        JSONResponse.render(result.status, result.body)
      rescue JSON::ParserError
        JSONResponse.render(400, error: "invalid_json")
      end

      router.get("/posts/top") do |req, _params|
        JSONResponse.render(200, Actions::TopPosts.call(limit: req.params["n"]))
      end

      router.get("/ips") { |_req, _p| JSONResponse.render(200, Actions::SharedIps.call) }

      router.post("/feedbacks") do |req, _params|
        body = JSONResponse.parse_body(req)
        result = Actions::AddFeedback.call(
          owner_id: body["owner_id"],
          comment:  body["comment"],
          post_id:  body["post_id"],
          user_id:  body["user_id"]
        )
        JSONResponse.render(result.status, result.body)
      rescue JSON::ParserError
        JSONResponse.render(400, error: "invalid_json")
      end

      router
    end
  end
end

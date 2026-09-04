# frozen_string_literal: true

module NinjaPost
  class Router
    Route = Struct.new(:http_method, :pattern, :param_names, :handler)

    def initialize
      @routes = []
    end

    def get(path, &handler)  = add("GET", path, handler)
    def post(path, &handler) = add("POST", path, handler)

    # The router IS the Rack app: call(env) -> [status, headers, body].
    def call(env)
      req = Rack::Request.new(env)
      route, params = find(req.request_method, req.path_info)
      return not_found(req) unless route

      route.handler.call(req, params)
    end

    private

    def add(http_method, path, handler)
      names = []
      # "/posts/:id" -> /\A\/posts\/([^\/]+)\z/, names = ["id"]
      source = path.gsub(%r{:(\w+)}) { names << Regexp.last_match(1); "([^/]+)" }
      @routes << Route.new(http_method, /\A#{source}\z/, names, handler)
    end

    def find(http_method, path_info)
      @routes.each do |route|
        next unless route.http_method == http_method

        match = route.pattern.match(path_info)
        next unless match

        return [route, route.param_names.zip(match.captures).to_h]
      end
      nil
    end

    def not_found(req)
      body = JSON.generate(error: "not_found", method: req.request_method)
      [404, { "content-type" => "application/json" }, [body]]
    end
  end
end

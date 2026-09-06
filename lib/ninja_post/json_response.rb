# frozen_string_literal: true

module NinjaPost
  # Turns a status + Ruby Hash into the Rack triple every handler returns.
  # Also gives a shared way to read a JSON request body.
  module JSONResponse
    module_function

    def render(status, hash)
      [status, { "content-type" => "application/json" }, [JSON.generate(hash)]]
    end

    # Reads and parses a JSON request body. Returns {} for an empty body,
    # raises JSON::ParserError for malformed JSON (callers decide how to
    # turn that into a 422).
    def parse_body(req)
      raw = req.body.read
      raw.empty? ? {} : JSON.parse(raw)
    end
  end
end

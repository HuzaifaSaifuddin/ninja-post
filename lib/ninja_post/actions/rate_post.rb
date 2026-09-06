# frozen_string_literal: true

module NinjaPost
  module Actions
    class RatePost
      Result = Struct.new(:status, :body)

      SQL = <<~SQL
        WITH new_rating AS (
          INSERT INTO ratings (post_id, value)
          VALUES (:post_id, :value)
          RETURNING id
        )
        UPDATE posts
        SET rating_sum   = rating_sum + :value,
            rating_count = rating_count + 1
        WHERE id = :post_id
        RETURNING rating_avg
      SQL

      def self.call(post_id:, value:)
        new(post_id:, value:).call
      end

      def initialize(post_id:, value:)
        @post_id = post_id
        @value   = value
      end

      def call
        return invalid_value unless @value.is_a?(Integer) && @value.between?(1, 5)

        post_id = Integer(@post_id, exception: false)
        return post_not_found unless post_id

        row = DB.fetch(SQL, post_id: post_id, value: @value).first
        return post_not_found unless row

        Result.new(200, { post_id: post_id, rating_average: row[:rating_avg].to_f })
      rescue Sequel::ForeignKeyConstraintViolation
        post_not_found
      end

      private

      def invalid_value
        Result.new(
          422,
          { errors: { value: ["must be an integer between 1 and 5"] } }
        )
      end

      def post_not_found
        Result.new(
          404,
          { error: "post_not_found" }
        )
      end
    end
  end
end

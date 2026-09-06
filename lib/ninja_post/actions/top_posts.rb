# frozen_string_literal: true

module NinjaPost
  module Actions
    class TopPosts
      DEFAULT_LIMIT = 10
      MAX_LIMIT     = 100

      def self.call(limit: nil)
        new(limit: limit).call
      end

      def initialize(limit:)
        @limit = clamp(limit)
      end

      def call
        DB[:posts]
          .select(:title, :content)
          .where { rating_count > 0 }
          .reverse(:rating_avg, :id)          # ORDER BY rating_avg DESC, id DESC
          .limit(@limit)
          .map { |r| { heading: r[:title], content: r[:content] } }
      end

      private

      def clamp(raw)
        n = Integer(raw, exception: false) || DEFAULT_LIMIT
        n.clamp(1, MAX_LIMIT)
      end
    end
  end
end

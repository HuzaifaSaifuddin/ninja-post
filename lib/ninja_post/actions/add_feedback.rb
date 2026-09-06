# frozen_string_literal: true

module NinjaPost
  module Actions
    class AddFeedback
      Result = Struct.new(:status, :body)

      def self.call(owner_id:, comment:, post_id: nil, user_id: nil)
        new(owner_id:, comment:, post_id:, user_id:).call
      end

      def initialize(owner_id:, comment:, post_id:, user_id:)
        @owner_id = Integer(owner_id, exception: false)
        @comment  = comment.to_s
        @post_id  = Integer(post_id, exception: false) if post_id
        @user_id  = Integer(user_id, exception: false) if user_id
      end

      def call
        errors = validate
        return Result.new(422, { errors: errors }) unless errors.empty?

        target = @post_id ? { post_id: @post_id } : { user_id: @user_id }

        DB[:feedbacks]
          .insert_conflict                       # ON CONFLICT DO NOTHING
          .insert(owner_id: @owner_id, comment: @comment, **target)

        Result.new(200, { feedbacks: feedback_list })
      rescue Sequel::ForeignKeyConstraintViolation
        Result.new(422, { errors: { target: ["owner or target does not exist"] } })
      end

      private

      def validate
        errors = {}
        errors[:owner_id] = ["is not present"] unless @owner_id
        errors[:comment]  = ["is not present"] if @comment.strip.empty?
        errors[:target]   = ["provide exactly one of post_id or user_id"] unless [@post_id, @user_id].compact.length == 1
        errors
      end

      def feedback_list
        DB[:feedbacks]
          .where(owner_id: @owner_id)
          .order(:id)
          .select(:id, :feedback_type, :post_id, :user_id, :comment, :created_at)
          .map { |r| r.merge(created_at: r[:created_at].iso8601) }
      end
    end
  end
end

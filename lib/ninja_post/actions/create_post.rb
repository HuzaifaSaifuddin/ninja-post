# frozen_string_literal: true

module NinjaPost
  module Actions
    class CreatePost
      Result = Struct.new(:status, :body)

      def self.call(login:, ip:, title:, content:)
        new(login:, ip:, title:, content:).call
      end

      def initialize(login:, ip:, title:, content:)
        @login   = login.to_s
        @ip      = ip
        @title   = title
        @content = content
      end

      def call
        return Result.new(422, { errors: { login: ["is not present"] } }) if @login.strip.empty?

        post = nil
        errors = nil

        DB.transaction do
          user_id = find_or_create_user_id(@login)
          post = Post.new(user_id: user_id, title: @title, content: @content, author_ip: @ip)

          unless post.valid?
            errors = post.errors
            raise Sequel::Rollback
          end

          post.save
          bump_ip_author(author_ip: post.author_ip, user_id: user_id)
        end

        return Result.new(422, { errors: errors }) if errors

        Result.new(200, serialize(post))
      end

      private

      # Race-free find-or-create: relies on the unique index on users.login.
      # Two concurrent requests for the same new login both land here; the
      # loser's INSERT hits the conflict and the no-op UPDATE makes RETURNING
      # still hand back the winner's row, so both callers get the same id.
      def find_or_create_user_id(login)
        DB[:users]
          .insert_conflict(target: :login, update: { login: Sequel[:excluded][:login] })
          .returning(:id)
          .insert(login: login)
          .first[:id]
      end

      # Keeps the ip_authors denormalization (action #4) in sync with every
      # post write, so that query never has to touch the posts table.
      def bump_ip_author(author_ip:, user_id:)
        DB[:ip_authors]
          .insert_conflict(
            target: %i[author_ip user_id],
            update: { posts_count: Sequel[:ip_authors][:posts_count] + 1 }
          )
          .insert(author_ip: author_ip, user_id: user_id, posts_count: 1)
      end

      def serialize(post)
        {
          id: post.id,
          user_id: post.user_id,
          title: post.title,
          content: post.content,
          author_ip: post.author_ip,
          rating_average: post.average_rating,
          created_at: post.created_at.iso8601
        }
      end
    end
  end
end

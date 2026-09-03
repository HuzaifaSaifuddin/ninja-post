# frozen_string_literal: true

module NinjaPost
  class Post < Sequel::Model(:posts)
    many_to_one :user,      key: :user_id
    one_to_many :ratings,   key: :post_id
    one_to_many :feedbacks, key: :post_id

    # rating_avg is a generated column: numeric coming back as a BigDecimal.
    # Expose a plain Float for JSON responses.
    def average_rating
      (rating_avg || 0).to_f
    end

    def validate
      super
      # validates_presence rejects nil, "", and whitespace-only ("   ") — that
      # covers the spec's "cannot be empty" for title/content.
      validates_presence %i[title content author_ip user_id]
      validates_max_length 255, :title, allow_nil: true
    end
  end
end

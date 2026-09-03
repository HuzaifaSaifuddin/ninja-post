# frozen_string_literal: true

module NinjaPost
  class Feedback < Sequel::Model(:feedbacks)
    many_to_one :owner, class: "NinjaPost::User", key: :owner_id
    many_to_one :post,  class: "NinjaPost::Post", key: :post_id
    many_to_one :user,  class: "NinjaPost::User", key: :user_id   # the *target* user

    def validate
      super
      validates_presence %i[owner_id comment]

      targets = [post_id, user_id].compact
      if targets.length != 1
        errors.add(:target, "provide exactly one of post_id or user_id")
      end
    end

    # 'post' or 'user' — straight from the generated column.
    def target_type = feedback_type
  end
end

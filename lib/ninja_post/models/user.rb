# frozen_string_literal: true

module NinjaPost
  class User < Sequel::Model(:users)
    one_to_many :posts,     key: :user_id
    one_to_many :feedbacks, key: :owner_id   # feedback this user has authored

    def validate
      super
      validates_presence :login
      validates_max_length 255, :login, allow_nil: false
      # DB has a unique index; this gives a friendly 422 instead of a raw
      # constraint error for the common (non-racy) case.
      validates_unique :login
    end
  end
end

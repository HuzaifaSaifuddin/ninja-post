# frozen_string_literal: true

module NinjaPost
  class Rating < Sequel::Model(:ratings)
    many_to_one :post, key: :post_id

    def validate
      super
      validates_presence %i[post_id value]
      validates_integer :value
      validates_includes (1..5), :value, message: "must be between 1 and 5"
    end
  end
end

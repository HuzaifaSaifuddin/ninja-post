# frozen_string_literal: true

module NinjaPost
  module Actions
    class SharedIps
      MIN_AUTHORS = 2

      def self.call = new.call

      def call
        DB[:ip_authors]
          .join(:users, id: :user_id)
          .group(Sequel[:ip_authors][:author_ip])
          .having { count.function.* >= MIN_AUTHORS }
          .select(
            Sequel[:ip_authors][:author_ip].as(:ip),
            Sequel.function(:array_agg, Sequel[:users][:login]).order(Sequel[:users][:login]).as(:authors)
          )
          .order(Sequel[:ip_authors][:author_ip])
          .map { |r| { ip: r[:ip], authors: Array(r[:authors]) } }
      end
    end
  end
end

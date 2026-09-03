# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:posts) do
      primary_key :id, type: :Bignum

      foreign_key :user_id, :users, type: :Bignum, null: false, on_delete: :cascade

      String :title,   null: false
      String :content, null: false, text: true

      # Author IP recorded per-post. `inet` is a native Postgres type: compact,
      # validated, and groupable — used by action #4 ("IPs with several authors").
      inet :author_ip, null: false

      # --- denormalized rating aggregates -------------------------------------
      # Updated atomically on every rate (action #2). Storing the running
      # sum + count lets "rate" be a single UPDATE and makes the average a
      # cheap read instead of an aggregate over the ratings table.
      Bignum  :rating_sum,   null: false, default: 0
      Integer :rating_count, null: false, default: 0

      # The average, computed by Postgres from sum/count and kept in sync
      # automatically. Because it's STORED we can index it for the top-N query.
      column :rating_avg, "numeric(6,4) GENERATED ALWAYS AS " \
             "(CASE WHEN rating_count = 0 THEN 0 " \
             " ELSE rating_sum::numeric / rating_count END) STORED"

      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :user_id, name: :posts_user_id_idx
    end

    # Top-N by average rating (action #3). Partial: only posts that have at
    # least one rating are eligible, so the index stays small and the query
    # never scans zero-rated posts.
    run <<~SQL
      CREATE INDEX posts_top_rated_idx
      ON posts (rating_avg DESC, id DESC)
      WHERE rating_count > 0
    SQL
  end
end

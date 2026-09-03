# frozen_string_literal: true

Sequel.migration do
  change do
    # One row per (author_ip, user_id) pair that has ever posted.
    # Maintained on post-create via INSERT ... ON CONFLICT. Bounded by
    # (distinct IPs) x (distinct authors) — a few thousand rows at most,
    # so action #4 never touches the posts table.
    create_table(:ip_authors) do
      inet    :author_ip, null: false
      foreign_key :user_id, :users, type: :Bignum, null: false, on_delete: :cascade

      # How many posts this author made from this IP. Not strictly needed for
      # action #4, but free to maintain and handy for diagnostics/seeds.
      Integer :posts_count, null: false, default: 0

      primary_key [:author_ip, :user_id], name: :ip_authors_pkey
      index :author_ip, name: :ip_authors_ip_idx
    end
  end
end

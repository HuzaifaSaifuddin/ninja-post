# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feedbacks) do
      primary_key :id, type: :Bignum

      # Who is leaving the feedback. "owner login" appears in the worker's XML.
      foreign_key :owner_id, :users, type: :Bignum, null: false, on_delete: :cascade

      # Exactly one of these is set (enforced by the CHECK below).
      foreign_key :post_id, :posts, type: :Bignum, null: true, on_delete: :cascade
      foreign_key :user_id, :users, type: :Bignum, null: true, on_delete: :cascade

      String :comment, null: false, text: true
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      # "feedback type (post or user)" for the worker — derived, never drifts.
      column :feedback_type,
             "text GENERATED ALWAYS AS " \
             "(CASE WHEN post_id IS NOT NULL THEN 'post' ELSE 'user' END) STORED"

      # A feedback points at a post XOR a user — never both, never neither.
      constraint(
        :feedbacks_exactly_one_target,
        Sequel.lit("(post_id IS NOT NULL)::int + (user_id IS NOT NULL)::int = 1")
      )

      # The action lists "feedback from the same owner"; the worker groups by owner.
      index :owner_id, name: :feedbacks_owner_id_idx
    end

    # "Check if the post or user already has feedback from the same owner."
    # Partial UNIQUE indexes enforce one-per-owner-per-target AND let the
    # create action use INSERT ... ON CONFLICT for a race-free check.
    run <<~SQL
      CREATE UNIQUE INDEX feedbacks_owner_post_uniq
      ON feedbacks (owner_id, post_id) WHERE post_id IS NOT NULL
    SQL
    run <<~SQL
      CREATE UNIQUE INDEX feedbacks_owner_user_uniq
      ON feedbacks (owner_id, user_id) WHERE user_id IS NOT NULL
    SQL
  end
end

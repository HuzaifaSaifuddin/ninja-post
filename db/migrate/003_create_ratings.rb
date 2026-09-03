# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:ratings) do
      primary_key :id, type: :Bignum

      foreign_key :post_id, :posts, type: :Bignum, null: false, on_delete: :cascade

      # 1..5, enforced in the database so no bad value can ever land, whatever
      # the caller does. smallint: 2 bytes instead of 4 — matters at millions of rows.
      column :value, "smallint", null: false

      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:ratings_value_range) { (value >= 1) & (value <= 5) }

      index :post_id, name: :ratings_post_id_idx
    end
  end
end

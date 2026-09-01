# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id, type: :Bignum
      String :login, null: false

      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      # Logins are unique and we look users up by login on every post-create
      # (find-or-create). A unique index enforces the rule AND serves the lookup.
      index :login, unique: true, name: :users_login_uniq
    end
  end
end

# frozen_string_literal: true
# Run: bundle exec ruby scratch/05_sequel_basics.rb
#
# Sequel over the same pg driver. Now we get: a connection pool, a query DSL,
# real Ruby types, block transactions, migrations, and easy raw SQL.

require "sequel"

# 0. Create the database using a temporary admin connection.
Sequel.connect("postgres:///postgres") do |admin|
  admin.run("DROP DATABASE IF EXISTS ninja_sequel_scratch")
  admin.run("CREATE DATABASE ninja_sequel_scratch")
end

# 1. Connect. This object owns a THREAD-SAFE connection pool.
DB = Sequel.connect("postgres:///ninja_sequel_scratch", max_connections: 4)
puts "connected, pool size: #{DB.pool.max_size}"

# 2. Schema via the migration DSL (here inline; real migrations live in files).
DB.create_table :users do
  primary_key :id
  String :login, null: false, unique: true
end

DB.create_table :posts do
  primary_key :id
  foreign_key :user_id, :users, null: false, on_delete: :cascade
  String  :title,   null: false
  String  :content, null: false, text: true
  String  :author_ip, null: false
  Integer :rating_sum,   null: false, default: 0
  Integer :rating_count, null: false, default: 0
  DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end

# 3. Datasets: chainable, lazy, return real types.
users = DB[:users]
alice_id = users.insert(login: "alice")
bob_id   = users.insert(login: "bob")
puts "alice_id = #{alice_id} (a #{alice_id.class})"   # Integer, not String

DB[:posts].multi_insert([
  { user_id: alice_id, title: "First",  content: "hello", author_ip: "10.0.0.1" },
  { user_id: alice_id, title: "Second", content: "world", author_ip: "10.0.0.2" },
  { user_id: bob_id,   title: "Bob's",  content: "hi",    author_ip: "10.0.0.1" },
])

# 4. Query DSL examples.
puts "post count: #{DB[:posts].count}"
puts "alice's titles: #{DB[:posts].where(user_id: alice_id).select_map(:title).inspect}"

# join + group + having: IPs used by more than one distinct author
rows = DB[:posts]
  .group(:author_ip)
  .having { count(distinct(:user_id)) > 1 }
  .select_map(:author_ip)
puts "shared IPs: #{rows.inspect}"

# 5. Block transaction — auto COMMIT on success, ROLLBACK on exception.
begin
  DB.transaction do
    DB[:users].insert(login: "carol")
    raise "boom"
  end
rescue => e
  puts "rolled back: #{e.message}"
end
puts "user count after rollback: #{DB[:users].count}"

# 6. Atomic UPDATE with a returned value — the pattern for concurrent ratings.
new_avg = DB[
  "UPDATE posts SET rating_sum = rating_sum + ?, rating_count = rating_count + 1 " \
  "WHERE id = ? RETURNING rating_sum::float / rating_count",
  5, DB[:posts].first[:id]
].single_value
puts "new average after atomic rate: #{new_avg}"

# 7. Raw SQL whenever you want it.
puts DB["SELECT login, count(*) AS n FROM posts JOIN users ON users.id = posts.user_id GROUP BY login"].all.inspect

DB.disconnect
puts "\nNote: Integer ids, real pool, block transactions, DSL + raw SQL side by side."

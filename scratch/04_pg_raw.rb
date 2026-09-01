# frozen_string_literal: true
# Run: bundle exec ruby scratch/04_pg_raw.rb
#
# The raw PostgreSQL driver. No pool, no DSL, no migrations. Just: open a
# socket, send SQL strings, get result objects back. This is what Sequel
# sits on top of.

require "pg"

# 1. Connect. Uses your local socket + current OS user (huzaifa) by default.
conn = PG.connect(dbname: "postgres")
puts "server: #{conn.exec('SELECT version()').getvalue(0, 0)}"

# 2. Create a throwaway database (can't CREATE DATABASE inside a transaction).
conn.exec("DROP DATABASE IF EXISTS ninja_pg_raw")
conn.exec("CREATE DATABASE ninja_pg_raw")
conn.close

# 3. Reconnect to it and build a tiny schema.
db = PG.connect(dbname: "ninja_pg_raw")
db.exec(<<~SQL)
  CREATE TABLE users (
    id    bigserial PRIMARY KEY,
    login text NOT NULL UNIQUE
  );
SQL

# 4. Parameterized insert ($1, $2...) — NEVER string-interpolate user input.
db.exec_params("INSERT INTO users (login) VALUES ($1), ($2)", ["alice", "bob"])

# 5. Query. Result rows come back as string-keyed hashes, values as strings.
res = db.exec("SELECT id, login FROM users ORDER BY id")
puts "columns: #{res.fields.inspect}"
res.each { |row| puts "  #{row.inspect}   (id is a #{row['id'].class})" }

# 6. Transactions are manual: BEGIN / COMMIT / ROLLBACK strings.
db.exec("BEGIN")
db.exec_params("INSERT INTO users (login) VALUES ($1)", ["carol"])
db.exec("ROLLBACK")
puts "count after rollback: #{db.exec('SELECT count(*) FROM users').getvalue(0, 0)}"

db.close
puts "\nNote: id came back as a String, no connection pool, transactions are raw SQL."

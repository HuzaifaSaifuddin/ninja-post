# frozen_string_literal: true

require_relative "../config/boot"
require "faker"
require "set"

BATCH          = 5_000
AUTHOR_COUNT   = 100
IP_COUNT       = 50
POST_COUNT     = Integer(ENV.fetch("SEED_POSTS", "200000"))
RATING_COUNT   = Integer(ENV.fetch("SEED_RATINGS", "500000"))
POST_FEEDBACKS = 10_000
USER_FEEDBACKS = 50

def log(msg) = puts "[seeds] #{msg}"

log "truncating all tables"
DB.run("TRUNCATE users, posts, ratings, feedbacks, ip_authors RESTART IDENTITY CASCADE")

# --- text pools: generate ~2k of each once, then sample -----------------------
log "building text pools"
TITLES   = Array.new(2_000) { Faker::Lorem.sentence(word_count: 4).delete_suffix(".") }
BODIES   = Array.new(2_000) { Faker::Lorem.paragraph(sentence_count: rand(3..8)) }
COMMENTS = Array.new(2_000) { Faker::Lorem.sentence(word_count: rand(6..15)) }

# --- authors ----------------------------------------------------------------
log "seeding #{AUTHOR_COUNT} authors"
logins = Array.new(AUTHOR_COUNT) { Faker::Internet.unique.username(specifier: 5..12) }
DB[:users].import([:login], logins.map { |l| [l] })
USER_IDS = DB[:users].select_map(:id)

# --- IP pool (ip_authors is backfilled after posts exist) --------------------
ip_set = Set.new
ip_set << Faker::Internet.ip_v4_address while ip_set.size < IP_COUNT
IPS = ip_set.to_a

log "authors=#{USER_IDS.size} ips=#{IPS.size}"

# --- posts ------------------------------------------------------------------
log "seeding #{POST_COUNT} posts"
DAY = 86_400
(1..POST_COUNT).each_slice(BATCH) do |slice|
  rows = slice.map do
    [USER_IDS.sample, TITLES.sample, BODIES.sample, IPS.sample, Time.now - rand(0..90) * DAY]
  end
  DB[:posts].import(%i[user_id title content author_ip created_at], rows)
end
log "posts=#{DB[:posts].count}"

# --- ip_authors backfill (denormalization behind GET /ips) -----------------
log "backfilling ip_authors"
DB.run(<<~SQL)
  INSERT INTO ip_authors (author_ip, user_id, posts_count)
  SELECT author_ip, user_id, COUNT(*)
  FROM posts
  GROUP BY author_ip, user_id
SQL
log "ip_authors=#{DB[:ip_authors].count}"

# --- ratings ---------------------------------------------------------------
log "seeding #{RATING_COUNT} ratings"
(1..RATING_COUNT).each_slice(BATCH) do |slice|
  rows = slice.map { [rand(1..POST_COUNT), rand(1..5)] }
  DB[:ratings].import(%i[post_id value], rows)
end
log "ratings=#{DB[:ratings].count}"

# --- backfill posts.rating_sum / rating_count (rating_avg is generated) ---
log "backfilling post rating aggregates"
DB.run(<<~SQL)
  UPDATE posts p
  SET rating_sum   = agg.s,
      rating_count = agg.c
  FROM (SELECT post_id, SUM(value) AS s, COUNT(*) AS c
        FROM ratings GROUP BY post_id) agg
  WHERE p.id = agg.post_id
SQL
log "rated posts=#{DB[:posts].where { rating_count > 0 }.count}"

# --- feedbacks -----------------------------------------------------------
log "seeding #{POST_FEEDBACKS} post-feedbacks"
seen = Set.new
rows = []
while rows.size < POST_FEEDBACKS
  owner = USER_IDS.sample
  post  = rand(1..POST_COUNT)
  next unless seen.add?([owner, post])       # respect feedbacks_owner_post_uniq
  rows << [owner, post, nil, COMMENTS.sample]
end
DB[:feedbacks].import(%i[owner_id post_id user_id comment], rows)

log "seeding #{USER_FEEDBACKS} user-feedbacks"
seen = Set.new
rows = []
while rows.size < USER_FEEDBACKS
  owner, target = USER_IDS.sample(2)          # 2 distinct => owner != target
  next unless seen.add?([owner, target])
  rows << [owner, nil, target, COMMENTS.sample]
end
DB[:feedbacks].import(%i[owner_id post_id user_id comment], rows)
log "feedbacks=#{DB[:feedbacks].count}"

# --- refresh planner stats after the bulk load -------------------------
log "ANALYZE"
DB.run("ANALYZE")
log "done"

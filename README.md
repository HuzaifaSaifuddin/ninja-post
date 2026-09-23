# NinjaPost

A JSON API service in plain Ruby — no Rails, no Sinatra. Built directly on
[Rack](https://github.com/rack/rack) + [Puma](https://github.com/puma/puma)
for HTTP, and [Sequel](https://sequel.jeremyevans.net/) + PostgreSQL for
persistence. Full requirements: [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Requirements

- Ruby ~> 3.3
- PostgreSQL (running locally, no password, current OS user — see
  `config/database.rb` if your setup differs)
- Bundler

## Setup

```bash
bundle install
./bin/db create
./bin/db migrate
```

`bin/db` manages the database for the current `APP_ENV`
(`development` by default): `create | drop | migrate | rollback | reset | version`.

## Running the server

```bash
bundle exec puma -p 9292 config.ru
```

```bash
curl localhost:9292/health
```

## Running the tests

Tests run against a separate `ninja_post_test` database.

```bash
APP_ENV=test ./bin/db reset
bundle exec ruby test/all.rb        # whole suite
bundle exec ruby test/rate_post_test.rb   # a single file
```

Each test runs inside a rolled-back transaction, so the test database stays
clean between runs. The one exception is the rating-concurrency test, which
needs real committed data visible across threads — it truncates tables
before/after itself instead (see `test/test_helper.rb`).

## Seeding data

```bash
bundle exec ruby db/seeds.rb
```

Builds ~100 authors, 50 IPs, 200,000 posts, 500,000 ratings, and 10,050
feedbacks (10,000 on posts + 50 on users) in a few seconds — bulk `import`
in batches, not one row at a time. `SEED_POSTS` / `SEED_RATINGS` env vars
override the volume for a smaller smoke-test run.

## The daily feedback export

```bash
bundle exec ruby bin/worker          # runs forever, fires at 09:00 daily
bundle exec ruby bin/worker --now    # also runs once immediately
```

Writes `tmp/feedbacks_export/feedbacks-<date>.xml`: every feedback with the
owner's login, comment, feedback type (`post`/`user`), and — for
post-feedback only — the post's average rating (empty for user-feedback).

## API

| Method | Path                  | Description |
|--------|-----------------------|--------------|
| GET    | `/health`             | liveness check |
| POST   | `/posts`              | create a post (creates the author if the login is new) |
| POST   | `/posts/:id/ratings`  | rate a post 1–5; returns the new average |
| GET    | `/posts/top?n=`       | top N posts by average rating (default/max: 10/100) |
| GET    | `/ips`                | IPs used by 2+ distinct authors, with their logins |
| POST   | `/feedbacks`          | leave feedback on a post or a user; returns the owner's full feedback list |

All responses are JSON. Validation failures return `422` as
`{"errors": {"field": ["message"]}}`; not-found returns `404`.

## Architecture

```
config.ru                    # rackup entrypoint: boots the app, runs it under Puma
config/boot.rb                # single load path shared by the server, tests, seeds, worker
config/database.rb             # Sequel connection, one DB per APP_ENV
db/migrate/                   # schema, hand-written (no Rails generators)
db/seeds.rb
lib/ninja_post/
  router.rb                   # minimal Rack-app dispatcher with path params
  json_response.rb            # JSON rendering + request-body parsing helpers
  app.rb                       # NinjaPost::App.build — wires routes to actions
  models/                     # thin Sequel::Model subclasses (validations only)
  actions/                     # one class per action (the actual business logic)
bin/db                         # create/drop/migrate/rollback/reset/version
bin/worker                    # daily feedback XML export
test/
```

Each of the 5 core actions lives in its own file under `lib/ninja_post/actions/`
and is callable independently of HTTP (`Action.call(...)`), which is what the
tests exercise directly or through `NinjaPost::App.build` via `rack-test`.

### Why this shape

- **No ActiveRecord.** Sequel gives migrations and a query DSL without pulling
  in Rails; its dataset API also makes raw, safe SQL easy for the
  performance-sensitive paths.
- **Denormalization, on purpose.** `posts.rating_sum` / `rating_count` +
  a `STORED` generated `rating_avg` column avoid recomputing an aggregate
  on every read; a partial index (`WHERE rating_count > 0`) serves the
  top-N query directly. An `ip_authors` pair table answers "which IPs have
  multiple authors" without ever touching the (200k+ row) `posts` table.
- **Concurrency-safe by construction, not by locking in Ruby.** Rating a
  post is a single SQL statement
  (`WITH insert ... UPDATE posts SET rating_sum = rating_sum + $v ...`)
  that lets Postgres's row lock serialize concurrent writes — verified in
  `test/rate_post_test.rb` with 50 real concurrent requests.
- **Race-free find-or-create.** Creating a post with a new author's login
  uses `INSERT ... ON CONFLICT (login) DO UPDATE ... RETURNING id` instead
  of a check-then-insert, so two concurrent requests for the same brand-new
  login can't collide.

## Verified performance

At the full seeded volume (200k posts / 500k ratings / 10k+ feedbacks),
every action completes well under the 100ms budget — most in single-digit
milliseconds (see commit history for `EXPLAIN ANALYZE` numbers).

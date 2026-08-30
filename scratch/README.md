# scratch/ — learning references (not part of the service)

Throwaway scripts that isolate each layer of the HTTP stack. Kept for reference
while building `ninja-post`. Safe to delete; excluded from the app and the specs.

| File | Layer | What it proves | Run |
|------|-------|----------------|-----|
| `01_rack_lib.rb` | the `rack` **gem** (library) | `Rack::Request` / `Rack::Response` / `Rack::MockRequest` / `Rack::Builder` all work with **zero network I/O**. This is the app-side ergonomics layer and the basis of `rack-test`. | `bundle exec ruby scratch/01_rack_lib.rb` |
| `02_puma_server.rb` | **puma** (HTTP server), no rack gem | The server builds the `env` hash from raw HTTP bytes and serializes the `[status, headers, body]` triple back. It does **not** parse query strings or JSON bodies for you. Its thread pool runs handlers **concurrently** (race demo + parallel-timing demo). | `bundle exec ruby scratch/02_puma_server.rb` then `curl localhost:9292/health` |
| `03_rackup_layer.rb` | **rackup** + `Rack::Builder` + middleware | `config.ru` is just Ruby evaluated in a `Rack::Builder`. Middleware = object `#call(env)` that wraps the next app. First `use` = outermost layer. `map` mounts sub-apps by path prefix. | `bundle exec ruby scratch/03_rackup_layer.rb` |

## The stack, bottom to top

```
TCP socket / HTTP parsing / thread pool ............ puma
        |  builds env hash, expects triple
env/triple contract + helper objects .............. rack (spec + gem)
        |  Rack::Request, Rack::Response, middleware
config.ru evaluated in Rack::Builder .............. rackup  (or `puma config.ru`)
        |  use ... / run ... / map ...
our router + action classes + models ............. ninja-post (to build)
```

## Key takeaways

- **`env` flows in, the triple flows out.** The server calls `app.call(env)`.
- **`rack.*` env keys come from the server**, not the rack gem. Puma sets them
  because the Rack SPEC says a conforming server must.
- **JSON bodies are never parsed for you.** Read `env["rack.input"]` /
  `req.body.read` and `JSON.parse` yourself.
- **`req.ip`** walks `X-Forwarded-For` past trusted proxies — that is what we
  use to record a post author's IP.
- **`rack.multithread == true`** under Puma → concurrent handler execution is
  real → the rating endpoint must be made safe at the database level.

# 🍜 Seasonal Ramen Chef (Ruby + OpenAI)

A small Sinatra app with an agent that proposes a season-aware ramen plan (style, broth, tare, noodles, toppings, garnish, method, shopping list) using a JSON-validated LLM response.

- Ruby 3.1+ (tested on 3.3/3.4)
- Sinatra + Puma
- OpenAI Ruby client
- JSON Schema validation (json_schemer)

## ✨ Features

- Season context from data/japanese_seasonal.yml (month → suggested ingredients)
- Strict JSON output (validated against a schema before returning)
- Clean UI (vanilla JS) with loading state & “Raw JSON” toggle
- Health/Version endpoints for basic monitoring
- CORS configurable via env

## 🚀 Quickstart

```bash
git clone <your-repo-url> seasonal-ramen-chef
cd seasonal-ramen-chef

# 1) Env
cp .env.sample .env
# put your real OPENAI_API_KEY=... into .env

# 2) One-time setup (project-local gems, like a Python .venv)
bundle exec rake setup

# 3) Run (auto-reload dev server)
bundle exec rake dev
# then open http://localhost:4567

# (optional) Plain server without auto-reload
bundle exec rake run

```

If `rake` isn’t found: `gem install bundler` (if needed), then `bundle install`, then retry `bundle exec` `rake setup`

## 🧩 Environment

`.env.sample` (copy to `.env` and edit):

```bash
BIND=0.0.0.0
PORT=4567
RACK_ENV=development
CORS_ORIGINS=http://localhost:4567

APP_VERSION=0.1.0
DEFAULT_LOCATION=Tokyo
DEFAULT_LOCALE=ja-JP

OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini

```

## 🧠 How it works

- `GET /` serves a minimal UI (`app.rb` inlined HTML, `public/app.js` for logic).
- `POST /api/recommend` calls the agent:
  - Builds season context from today’s date and `DEFAULT_LOCATION`.
  - Prompts the model with a schema and requests `response_format: json_object`.
  - Validates the model JSON with `json_schemer`. If it fails, returns a graceful `fallback`.

### Schema (short version)

```ruby
{
  "type" => "object",
  "properties" => {
    "season_context" => {
      "type" => "object",
      "properties" => {
        "date" => { "type" => "string" },
        "month" => { "type" => "string" },
        "location" => { "type" => "string" },
        "suggested_ingredients" => { "type" => "array", "items" => { "type" => "string" } }
      },
      "required" => %w[date month location suggested_ingredients],
      "additionalProperties" => false
    },
    "style" => { "type" => "string" },
    "broth" => { "type" => "string" },
    "tare"  => { "type" => "string" },
    "noodles" => { "type" => "string" },
    "toppings" => { "type" => "array", "items" => { "type" => "string" } },
    "garnish"  => { "type" => "array", "items" => { "type" => "string" } },
    "method_steps" => { "type" => "array", "items" => { "type" => "string" } },
    "shopping_list" => { "type" => "array", "items" => { "type" => "string" } },
    "serving_note" => { "type" => "string" }
  },
  "required" => %w[season_context style broth tare noodles toppings garnish method_steps shopping_list serving_note],
  "additionalProperties" => false
}


```

## 🔌 Endpoints

- `GET /` — UI
- `POST /api/recommend` — returns the ramen plan (application/json)
- `GET /health` — `{ "ok": true }`
- `GET /version` — `{ "name": "seasonal-ramen-chef", "version": "0.1.0" }`

### cURL example

```bash
curl -s -X POST http://localhost:4567/api/recommend \
  -H "Content-Type: application/json" \
  -d '{"location":"Tokyo","language":"en-US","notes":"prefer lighter soups"}' | jq


```

## 🧰 Local dev tips

- Run (no Docker):

```bash
bundle exec puma -C puma.rb
# or with auto-reload:
bundle exec rerun --pattern "**/*.{rb,js,yml,erb}" -- bundle exec puma -C puma.rb

```

- Optional bin scripts (create if you like):
  - `bin/setup` → installs gems to `vendor/bundle`
  - `bin/dev` → runs `rerun` + `puma`
  - `bin/server` → runs `puma`

## ⚡ Performance tips

- Use a smaller/faster model (already set to `gpt-4o-mini` by default).
- Lower `temperature` (e.g., `0.5–0.7`) to reduce retries/variance.
- Keep prompts concise; you’re already using `response_format: json_object` which helps.
- Network latency dominates—close to the API region = faster.

Want to experiment with non-cloud backends later? The OpenAI Ruby client can be pointed at a different base URL if it’s API-compatible. You’d set an alternate API base in initialization and adjust the model id. (Keep JSON schema validation on.)

🧪 Troubleshooting

- Browser shows nothing at `0.0.0.0:4567`: Use `http://localhost:4567/` (bind vs host).
- JS error: “Cannot set properties of null”: The new `app.js` renders a single HTML block and won’t query missing IDs, fixing this.
- Schema error: You’ll now get a helpful message with the failing keyword/path. Adjust the prompt or schema accordingly.
- Windows build errors: Ensure RubyInstaller DevKit/MSYS2 is installed; rerun `bundle install`.

📁 Project layout (key files)

```txt
.
├─ app.rb                 # Sinatra app (serves UI + API)
├─ services/
│  └─ ramen_agent.rb      # Agent logic + schema + OpenAI call + validation
├─ public/
│  └─ app.js              # Frontend logic (safe render, loading state)
├─ data/
│  └─ japanese_seasonal.yml
├─ puma.rb
├─ Gemfile / Gemfile.lock
├─ .env.sample  (# copy to .env)
└─ config.ru

```

📜 License

MIT (or your choice)

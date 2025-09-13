# app.rb
# frozen_string_literal: true

require "bundler/setup"
Bundler.require

require "sinatra"
require "sinatra/json"
require "dotenv"
require "oj"
require_relative "services/ramen_agent"

Dotenv.load(File.expand_path("resources/.env", __dir__))

set :bind, ENV["BIND"] || "0.0.0.0"
set :port, (ENV["PORT"] || 4567).to_i
set :server, :puma
set :public_folder, File.expand_path("public", __dir__)

use Rack::Cors do
  allow do
    origins "*"
    resource "*", headers: :any, methods: %i[get post options]
  end
end

get "/" do
  <<~HTML
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width,initial-scale=1" />
      <title>Seasonal Ramen Chef</title>
      <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji"; margin: 2rem; max-width: 840px; }
        .card { border: 1px solid #ddd; border-radius: 14px; padding: 16px; margin: 12px 0; box-shadow: 0 2px 6px rgba(0,0,0,.04); }
        label { display:block; margin: 8px 0 4px; font-weight: 600; }
        input, select, button, textarea { width: 100%; padding: 10px; border-radius: 10px; border: 1px solid #ccc; }
        button { cursor: pointer; font-weight: 700; }
        pre { white-space: pre-wrap; word-wrap: break-word; }
      </style>
    </head>
    <body>
      <h1>🍜 Seasonal Ramen Chef (Ruby + OpenAI)</h1>
      <p>Generate a season-aware ramen plan with a single click.</p>

      <div class="card">
        <label>Location (optional)</label>
        <input id="location" placeholder="Tokyo" />

        <label>Language</label>
        <select id="language">
          <option value="ja-JP">日本語</option>
          <option value="en-US">English</option>
        </select>

        <label>Notes / Preferences (optional)</label>
        <textarea id="notes" placeholder="E.g., prefer lighter soups, vegetarian, spicy, etc."></textarea>

        <button id="go">Generate Plan</button>
      </div>

      <div id="result" class="card" style="display:none"></div>

      <script src="/app.js"></script>
    </body>
  </html>
  HTML
end

post "/api/recommend" do
  content_type :json
  req = request.body.read
  begin
    payload = req && !req.empty? ? Oj.load(req) : {}
  rescue
    payload = {}
  end

  agent = RamenAgent.new
  result = agent.recommend(
    user_prefs: {
      location: payload["location"],
      language: payload["language"],
      notes:    payload["notes"]
    }.compact
  )

  json result
end

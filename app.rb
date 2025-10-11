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
    origins ENV.fetch("CORS_ORIGINS", "http://localhost:4567").split(",")
    resource "*", headers: :any, methods: %i[get post options]
  end
end

# ✅ Health + Version Endpoints
get "/health" do
  json ok: true
end

get "/version" do
  json name: "seasonal-ramen-chef", version: ENV["APP_VERSION"] || "0.1.0"
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
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            margin: 2rem;
            max-width: 640px;
            margin-left: auto;
            margin-right: auto;
            background: #f7f9fc;
            color: #333;
          }

          h1 {
            font-size: 1.8rem;
            margin-bottom: 0.5rem;
          }

          p {
            font-size: 1rem;
            color: #555;
          }

          .card {
            background: #fff;
            border: 1px solid #ddd;
            border-radius: 12px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
          }

          label {
            display: block;
            margin: 12px 0 6px;
            font-weight: 600;
          }

          input, select, textarea, button {
            width: 100%;
            padding: 10px;
            margin-top: 4px;
            border: 1px solid #ccc;
            border-radius: 8px;
            font-size: 1rem;
          }

          button {
            background: #ff5722;
            color: white;
            font-weight: bold;
            border: none;
            margin-top: 16px;
            transition: background 0.2s ease;
            cursor: pointer;
          }

          button:hover {
            background: #e64a19;
          }

          pre {
            white-space: pre-wrap;
            word-wrap: break-word;
            font-size: 0.95rem;
          }
        </style>
      </head>
      <body>
        <h1>🍜 Seasonal Ramen Chef</h1>
        <p>Generate a season-aware ramen plan with one click.</p>

        <div class="card">
          <label>Location (optional)</label>
          <input id="location" placeholder="e.g., Tokyo, Osaka, Sapporo" />

          <label>Language</label>
          <select id="language">
            <option value="ja-JP">日本語</option>
            <option value="en-US">English</option>
          </select>

          <label>Notes / Preferences (optional)</label>
          <textarea id="notes" placeholder="E.g., spicy, no pork, prefer tsukemen..."></textarea>

          <button id="go">Generate Plan</button>
        </div>

        <div id="result" class="card" style="display:none"></div>
        <div id="seasonDate" class="card" style="display:none"></div>

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

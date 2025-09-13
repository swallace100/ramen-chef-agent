# services/ramen_agent.rb
# frozen_string_literal: true

require "openai"
require "oj"
require "date"
require "yaml"

class RamenAgent
  Schema = {
    type: "object",
    properties: {
      season_context: { type: "string" },
      style:          { type: "string", description: "Ramen style, e.g., shoyu, shio, miso, tonkotsu, tori-paitan" },
      broth:          { type: "string", description: "Short broth concept & why it fits the season" },
      tare:           { type: "string", description: "Season-appropriate tare idea (e.g., light shoyu with yuzu zest)" },
      noodles:        { type: "string", description: "Noodle thickness/shape & cook tips" },
      toppings:       { type: "array", items: { type: "string" } },
      garnish:        { type: "array", items: { type: "string" } },
      method_steps:   { type: "array", items: { type: "string" } },
      shopping_list:  { type: "array", items: { type: "string" } },
      serving_note:   { type: "string" }
    },
    required: %i[season_context style broth tare noodles toppings garnish method_steps shopping_list serving_note]
  }

  def initialize(
    api_key: ENV["OPENAI_API_KEY"],
    model: ENV["OPENAI_MODEL"] || "gpt-4o-mini",
    seasonal_yaml_path: File.expand_path("../../data/japanese_seasonal.yml", __dir__)
  )
    @client = OpenAI::Client.new(access_token: api_key)
    @model = model
    @seasonal_map = File.exist?(seasonal_yaml_path) ? YAML.load_file(seasonal_yaml_path) : {}
  end

  # Basic “season-aware” context using month + a tiny ingredient map.
  def season_context(location: ENV["DEFAULT_LOCATION"] || "Tokyo", now: Time.now)
    month = now.month.to_s
    picks = Array(@seasonal_map[month]).uniq
    {
      date: now.strftime("%Y-%m-%d"),
      month: month,
      location: location,
      suggested_ingredients: picks
    }
  end

  def recommend(user_prefs: {})
    ctx = season_context(location: user_prefs[:location] || ENV["DEFAULT_LOCATION"])
    cuisine_lang = user_prefs[:language] || (ENV["DEFAULT_LOCALE"] || "ja-JP")

    sys = <<~SYS
      You are “Seasonal Ramen Chef,” an expert ramen consultant for home cooks.
      Goal: propose a seasonally-appropriate ramen (Japan context), concise but complete.
      Consider date, month, and location climate generally; prefer produce and garnishes that fit the season.
      Output MUST be valid JSON matching the provided schema. Keep ingredient names simple in English or romaji if needed.
      If language is ja-JP, write natural Japanese; else default to concise English.
    SYS

    user = <<~USR
      Context:
      #{Oj.dump(ctx, mode: :compat)}

      User preferences (optional):
      #{Oj.dump(user_prefs, mode: :compat)}

      Please return JSON with fields:
      #{Oj.dump(Schema, mode: :compat)}
    USR

    response = @client.chat(
      parameters: {
        model: @model,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: sys },
          { role: "user",   content: user }
        ],
        temperature: 0.8
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    Oj.load(raw, mode: :strict)
  rescue StandardError => e
    {
      "error" => e.message,
      "fallback" => {
        "season_context" => "Could not reach model. Try again.",
        "style" => "shio",
        "broth" => "Light chicken dashi with kombu; easy, clean, and season-neutral.",
        "tare" => "Light shio tare with a dash of yuzu zest.",
        "noodles" => "Medium-thin straight noodles, ~1:45–2:00 min.",
        "toppings" => ["negi", "menma", "chashu (store-bought ok)"],
        "garnish" => ["nori", "yuzu peel"],
        "method_steps" => [
          "Warm dashi; season with shio tare.",
          "Cook noodles to firmness; drain well.",
          "Assemble bowl: tare + broth, then noodles, toppings, garnish."
        ],
        "shopping_list" => ["kombu dashi", "shio tare", "negi", "nori", "menma", "yuzu"],
        "serving_note" => "Keep it light; highlight aromatics."
      }
    }
  end
end

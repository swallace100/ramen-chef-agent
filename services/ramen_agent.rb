require "openai"
require "oj"
require "date"
require "yaml"
require "json_schemer"

class RamenAgent
  Schema = {
    "type" => "object",
    "properties" => {
      "season_context" => {
        "type" => "object",
        "properties" => {
          "date" => { "type" => "string" },          # e.g., "2025-10-11" (ISO date string)
          "month" => { "type" => "string" },         # returning "10" as a string
          "location" => { "type" => "string" },
          "suggested_ingredients" => {
            "type" => "array",
            "items" => { "type" => "string" }
          }
        },
        "required" => %w[date month location suggested_ingredients],
        "additionalProperties" => false
      },

      "style" =>          { "type" => "string" },
      "broth" =>          { "type" => "string" },
      "tare"  =>          { "type" => "string" },
      "noodles" =>        { "type" => "string" },
      "toppings" =>       { "type" => "array", "items" => { "type" => "string" } },
      "garnish" =>        { "type" => "array", "items" => { "type" => "string" } },
      "method_steps" =>   { "type" => "array", "items" => { "type" => "string" } },
      "shopping_list" =>  { "type" => "array", "items" => { "type" => "string" } },
      "serving_note" =>   { "type" => "string" }
    },
    "required" => %w[
      season_context style broth tare noodles toppings garnish method_steps shopping_list serving_note
    ],
    "additionalProperties" => false
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

  def schemer
    @schemer ||= JSONSchemer.schema(Schema)
  end

  def recommend(user_prefs: {})
    ctx = season_context(location: user_prefs[:location] || ENV["DEFAULT_LOCATION"])
    cuisine_lang = user_prefs[:language] || (ENV["DEFAULT_LOCALE"] || "ja-JP")

    sys = <<~SYS
      You are “Seasonal Ramen Chef,” an expert ramen consultant for home cooks.
      Goal: propose a seasonally-appropriate ramen (Japan context), concise but complete.
      Consider date, month, and location climate; prefer produce/garnishes that fit the season.
      Output MUST be valid JSON matching the provided schema exactly.
      If language is ja-JP, write natural Japanese; else concise English.
    SYS

    user = <<~USR
      Context:
      #{Oj.dump(ctx, mode: :compat)}

      User preferences (optional):
      #{Oj.dump(user_prefs, mode: :compat)}

      Schema (enforced):
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
        temperature: 0.7
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    plan = Oj.load(raw, mode: :strict)

    unless schemer.valid?(plan)
      errors = schemer.validate(plan).to_a
      if errors.any?
        friendly = errors.take(3).map do |e|
          path = (e["data_pointer"] || e["dataPath"] || e["path"] || []).to_s
          "#{e['type'] || e['keyword']}: at #{path} #{e['schema'] ? "expected #{e['schema']}" : ''}"
        end
        raise "Model JSON failed schema:\n - " + friendly.join("\n - ")
      else
        raise "Model JSON failed schema (no details)"
      end
    end

    plan
  rescue StandardError => e
    {
      "error" => e.message,
      "fallback" => {
        "season_context" => season_context,
        "style" => "shio",
        "broth" => "Light chicken/kombu dashi; season-neutral and clean.",
        "tare" => "Shio tare with a touch of citrus (yuzu if in season).",
        "noodles" => "Medium-thin straight; ~1:45–2:00.",
        "toppings" => ["negi", "menma", "chashu (store-bought ok)"],
        "garnish" => ["nori", "yuzu peel"],
        "method_steps" => [
          "Warm dashi; season with shio tare.",
          "Cook noodles; drain well.",
          "Assemble bowl: tare+broth, noodles, toppings, garnish."
        ],
        "shopping_list" => ["kombu dashi", "shio tare", "negi", "nori", "menma", "yuzu"],
        "serving_note" => "Keep it light; highlight aromatics."
      }
    }
  end
end

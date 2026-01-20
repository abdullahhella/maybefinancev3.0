# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :synth_api_key, type: :string, default: ENV["SYNTH_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :llm_provider, type: :string, default: ENV["LLM_PROVIDER"]
  field :llm_model, type: :string, default: ENV["LLM_MODEL"].presence || "gpt-4.1"
  field :ollama_base_url, type: :string, default: ENV["OLLAMA_BASE_URL"]

  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end

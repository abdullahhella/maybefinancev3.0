class Provider::Registry
  include ActiveModel::Validations

  Error = Class.new(StandardError)

  CONCEPTS = %i[exchange_rates securities llm]

  validates :concept, inclusion: { in: CONCEPTS }

  class << self
    def for_concept(concept)
      new(concept.to_sym)
    end

    def get_provider(name)
      send(name)
    rescue NoMethodError
      raise Error.new("Provider '#{name}' not found in registry")
    end

      def plaid_provider_for_region(region)
        region.to_sym == :us ? plaid_us : plaid_eu
      end

      private
      def llm
        provider_name = llm_provider_names.first

        return nil unless provider_name.present?

        send(provider_name)
      end

      def stripe
        secret_key = ENV["STRIPE_SECRET_KEY"]
        webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

        return nil unless secret_key.present? && webhook_secret.present?

        Provider::Stripe.new(secret_key:, webhook_secret:)
      end

      def synth
        api_key = ENV.fetch("SYNTH_API_KEY", Setting.synth_api_key)

        return nil unless api_key.present?

        Provider::Synth.new(api_key)
      end

      def plaid_us
        config = Rails.application.config.plaid

        return nil unless config.present?

        Provider::Plaid.new(config, region: :us)
      end

      def plaid_eu
        config = Rails.application.config.plaid_eu

        return nil unless config.present?

        Provider::Plaid.new(config, region: :eu)
      end

      def github
        Provider::Github.new
      end

      def openai
        access_token = ENV.fetch("OPENAI_ACCESS_TOKEN", Setting.openai_access_token)

        return nil unless access_token.present?

        Provider::Openai.new(access_token)
      end

      def ollama
        base_url = ENV.fetch("OLLAMA_BASE_URL", Setting.ollama_base_url)

        return nil unless base_url.present?

        model = ENV["LLM_MODEL"].presence || Setting.llm_model

        Provider::Ollama.new(base_url: base_url, model: model)
      end

      def llm_provider_names
        preferred = ENV.fetch("LLM_PROVIDER", Setting.llm_provider).presence
        preferred = preferred.to_s.downcase.to_sym if preferred.present?
        providers = []
        providers << :openai if openai_available?
        providers << :ollama if ollama_available?

        if preferred.present?
          return [preferred] if providers.include?(preferred)
          return []
        end

        providers
      end

      def openai_available?
        ENV.fetch("OPENAI_ACCESS_TOKEN", Setting.openai_access_token).present?
      end

      def ollama_available?
        ENV.fetch("OLLAMA_BASE_URL", Setting.ollama_base_url).present?
      end
  end

  def initialize(concept)
    @concept = concept
    validate!
  end

  def providers
    available_providers.map { |p| self.class.send(p) }
  end

  def get_provider(name)
    provider_method = available_providers.find { |p| p == name.to_sym }

    raise Error.new("Provider '#{name}' not found for concept: #{concept}") unless provider_method.present?

    self.class.send(provider_method)
  end

  private
    attr_reader :concept

    def available_providers
      case concept
      when :exchange_rates
        %i[synth]
      when :securities
        %i[synth]
      when :llm
        self.class.send(:llm_provider_names)
      else
        %i[synth plaid_us plaid_eu github openai ollama]
      end
    end
end

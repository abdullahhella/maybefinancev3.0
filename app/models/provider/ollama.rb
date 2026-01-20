class Provider::Ollama < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Ollama::Error
  Error = Class.new(Provider::Error)

  def initialize(base_url:, model:)
    @base_url = base_url
    @default_model = model
  end

  def supports_model?(model)
    model.present?
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        model: default_model,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        model: default_model,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        prompt: prompt,
        instructions: instructions,
        functions: functions,
        function_results: function_results
      )

      response = client.post(chat_path) do |req|
        req.body = chat_config.payload(model: model_for(model))
      end

      parsed = ChatParser.new(JSON.parse(response.body)).parsed

      emit_stream(streamer, parsed) if streamer.present?

      parsed
    end
  end

  private
    attr_reader :base_url, :default_model

    def model_for(requested_model)
      requested_model.presence || default_model
    end

    def chat_path
      "/api/chat"
    end

    def normalized_base_url
      base = base_url.to_s.strip
      base = base.sub(%r{/+\z}, "")
      base.sub(%r{/api\z}, "")
    end

    def client
      @client ||= Faraday.new(url: normalized_base_url) do |faraday|
        faraday.request :json
        faraday.response :raise_error
      end
    end

    def emit_stream(streamer, parsed)
      message = parsed.messages.first

      if message&.output_text.present?
        streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: message.output_text))
      end

      streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: parsed))
    end
end

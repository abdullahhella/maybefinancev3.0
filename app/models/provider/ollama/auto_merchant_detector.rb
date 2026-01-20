class Provider::Ollama::AutoMerchantDetector
  def initialize(client, model:, transactions:, user_merchants:)
    @client = client
    @model = model
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    response = client.post("/api/chat") do |req|
      req.body = {
        model: model,
        messages: [
          { role: "system", content: instructions },
          { role: "user", content: developer_message }
        ],
        format: "json"
      }
    end

    parsed = JSON.parse(response.body)
    content = parsed.dig("message", "content")

    raise Provider::Ollama::Error, "Ollama response missing content" if content.blank?

    response_json = JSON.parse(content)

    build_response(response_json.dig("merchants"))
  end

  private
    attr_reader :client, :model, :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def build_response(categorizations)
      Array(categorizations).map do |categorization|
        AutoDetectedMerchant.new(
          transaction_id: categorization.dig("transaction_id"),
          business_name: normalize_ai_value(categorization.dig("business_name")),
          business_url: normalize_ai_value(categorization.dig("business_url")),
        )
      end
    end

    def normalize_ai_value(ai_value)
      return nil if ai_value == "null"

      ai_value
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
        Here are the user's available merchants in JSON format:

        ```json
        #{user_merchants.to_json}
        ```

        Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Return "null" if you are not 80%+ confident in your answer.
        Respond with JSON that matches the requested schema.
      MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
        You are an assistant to a consumer personal finance app.

        Return a JSON object with a top-level "merchants" array where each item contains:
        - transaction_id
        - business_name
        - business_url

        Closely follow ALL the rules below while auto-detecting business names and website URLs:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
        - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
        - Be slightly pessimistic. We favor returning "null" over returning a false positive.
        - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

        Determining a value:

        - First attempt to determine the name + URL from your knowledge of global businesses
        - If no certain match, attempt to match one of the user-provided merchants
        - If no match, return "null"

        Example 1 (known business):

        ```
        Transaction name: "Some Amazon purchases"

        Result:
        - business_name: "Amazon"
        - business_url: "amazon.com"
        ```

        Example 2 (generic business):

        ```
        Transaction name: "local diner"

        Result:
        - business_name: null
        - business_url: null
        ```
      INSTRUCTIONS
    end
end

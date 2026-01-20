class Provider::Ollama::ChatConfig
  def initialize(prompt:, instructions:, functions:, function_results:)
    @prompt = prompt
    @instructions = instructions
    @functions = functions
    @function_results = function_results
  end

  def payload(model:)
    {
      model: model,
      messages: messages,
      tools: tools.presence
    }.compact
  end

  private
    attr_reader :prompt, :instructions, :functions, :function_results

    def messages
      message_items = []
      message_items << { role: "system", content: instructions } if instructions.present?
      message_items << { role: "user", content: prompt }

      function_results.each do |result|
        message_items << {
          role: "tool",
          tool_call_id: result[:call_id],
          content: result[:output].to_json
        }
      end

      message_items
    end

    def tools
      functions.map do |fn|
        {
          type: "function",
          function: {
            name: fn[:name],
            description: fn[:description],
            parameters: fn[:params_schema]
          }
        }
      end
    end
end

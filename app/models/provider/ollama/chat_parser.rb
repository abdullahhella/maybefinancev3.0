require "securerandom"

class Provider::Ollama::ChatParser
  def initialize(object)
    @object = object
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      object.dig("id") || SecureRandom.uuid
    end

    def response_model
      object.dig("model")
    end

    def response_message
      object.dig("message") || {}
    end

    def messages
      content = response_message.dig("content")
      return [] if content.blank?

      [ChatMessage.new(id: response_id, output_text: content)]
    end

    def function_requests
      tool_calls = response_message.dig("tool_calls") || []

      tool_calls.map do |call|
        function = call.dig("function") || {}
        args = function.dig("arguments")
        args_json = args.is_a?(String) ? args : args.to_json
        call_id = call.dig("id") || SecureRandom.uuid

        ChatFunctionRequest.new(
          id: call_id,
          call_id: call_id,
          function_name: function.dig("name"),
          function_args: args_json
        )
      end
    end
end

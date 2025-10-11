require_relative "_base_provider"
require_relative "open_ai/options"

require_gem!(:openai, __FILE__)

module ActiveAgent
  module GenerationProvider
    class OpenAIProvider < BaseProvider
      include StreamProcessing
      include MessageFormatting
      include ToolManagement

      attr_reader :options

      def initialize(options)
        super
        @options = namespace::Options.new(**options.except("service"))
      end

      # @return [OpenAI::Client]
      def client(prompt_options = nil)
        if prompt_options
          ::OpenAI::Client.new(namespace::Options.new(prompt_options).client_options)
        else
          @client ||= ::OpenAI::Client.new(@options.client_options)
        end
      end

      def generate(prompt)
        @prompt = prompt

        with_error_handling do
          if @prompt.multimodal? || @prompt.content_type == "multipart/mixed"
            responses_prompt(parameters: responses_parameters)
          else
            chat_prompt(parameters: prompt_parameters)
          end
        end
      end

      def embed(prompt)
        @prompt = prompt

        with_error_handling do
          embeddings_prompt(parameters: embeddings_parameters)
        end
      end

      protected

      def namespace = OpenAI

      # Override from StreamProcessing module
      def process_stream_chunk(chunk, message, agent_stream)
        new_content = chunk.dig("choices", 0, "delta", "content")
        if new_content && !new_content.blank?
          message.generation_id = chunk.dig("id")
          message.content += new_content
          # Call agent_stream directly without the block to avoid double execution
          agent_stream&.call(message, new_content, false, prompt.action_name)
        elsif chunk.dig("choices", 0, "delta", "tool_calls") && chunk.dig("choices", 0, "delta", "role")
          message = handle_message(chunk.dig("choices", 0, "delta"))
          prompt.messages << message
          @response = ActiveAgent::GenerationProvider::Response.new(prompt:, message:)
        end

        if chunk.dig("choices", 0, "finish_reason")
          finalize_stream(message, agent_stream)
        end
      end

      # Override from MessageFormatting module to handle OpenAI image format
      def format_image_content(message)
        [ {
          type: "image_url",
          image_url: { url: message.content }
        } ]
      end

      private

      # Now using modules, but we can override build_provider_parameters for OpenAI-specific needs
      # The prompt_parameters method comes from ParameterBuilder module
      # The format_tools method comes from ToolManagement module
      # The provider_messages method comes from MessageFormatting module

      def chat_response(response)
        return @response if prompt.options[:stream]
        message_json = response.dig("choices", 0, "message")
        message_json["id"] = response.dig("id") if message_json["id"].blank?
        message = handle_message(message_json)

        update_context(prompt: prompt, message: message, response: response)

        @response = ActiveAgent::GenerationProvider::Response.new(prompt: prompt, message: message, raw_response: response)
      end

      def responses_response(response)
        message_json = response["output"].find { |output_item| output_item["type"] == "message" }
        message_json["id"] = response.dig("id") if message_json["id"].blank?

        message = ActiveAgent::ActionPrompt::Message.new(
          generate_id: message_json["id"],
          content: message_json["content"].first["text"],
          role: message_json["role"].intern,
          action_requested: message_json["finish_reason"] == "tool_calls",
          raw_actions: message_json["tool_calls"] || [],
          content_type: prompt.output_schema.present? ? "application/json" : "text/plain",
        )

        @response = ActiveAgent::GenerationProvider::Response.new(prompt: prompt, message: message, raw_response: response)
      end

      def handle_message(message_json)
        ActiveAgent::ActionPrompt::Message.new(
          generation_id: message_json["id"],
          content: message_json["content"],
          role: message_json["role"].intern,
          action_requested: message_json["finish_reason"] == "tool_calls",
          raw_actions: message_json["tool_calls"] || [],
          requested_actions: handle_actions(message_json["tool_calls"])
        )
      end

      # handle_actions is now provided by ToolManagement module

      # @todo prompt_parameters client options overriding
      def chat_prompt(parameters: prompt_parameters)
        parameters[:stream] = provider_stream if prompt.options[:stream] || config["stream"]
        chat_response(client.chat(parameters: parameters))
      end

      # @todo prompt_parameters client options overriding
      def responses_prompt(parameters: responses_parameters)
        # parameters[:stream] = provider_stream if prompt.options[:stream] || config["stream"]
        responses_response(client.responses.create(parameters: parameters))
      end

      def responses_parameters(model: @prompt.options[:model] || @model_name, messages: @prompt.messages, temperature: @prompt.options[:temperature] || @config["temperature"] || 0.7, tools: @prompt.actions, structured_output: @prompt.output_schema)
        {
          model: model,
          input: ActiveAgent::GenerationProvider::ResponsesAdapter.new(@prompt).input,
          tools: tools.presence,
          text: structured_output
        }.compact
      end

      def embeddings_parameters(input: prompt.message.content, model: "text-embedding-3-large")
        {
          model: model,
          input: input
        }
      end

      def embeddings_response(response)
        message = ActiveAgent::ActionPrompt::Message.new(content: response.dig("data", 0, "embedding"), role: "assistant")

        @response = ActiveAgent::GenerationProvider::Response.new(prompt: prompt, message: message, raw_response: response)
      end

      # @todo prompt_parameters client options overriding
      def embeddings_prompt(parameters:)
        embeddings_response(client.embeddings(parameters: embeddings_parameters))
      end
    end
  end
end

require "openai"
require_relative "open_ai_provider"

module ActiveAgent
  module GenerationProvider
    class OpenRouterProvider < OpenAIProvider
      def initialize(config)
        @config = config
        @access_token ||= config["api_key"] || config["access_token"] || ENV["OPENROUTER_API_KEY"] || ENV["OPENROUTER_ACCESS_TOKEN"]
        @model_name = config["model"]
        @client = OpenAI::Client.new(uri_base: "https://openrouter.ai/api/v1", access_token: @access_token, log_errors: true)
      end

      private

      # Override to add plugins support for OpenRouter
      def prompt_parameters(model: @prompt.options[:model] || @model_name, messages: @prompt.messages, temperature: @prompt.options[:temperature] || @config["temperature"] || 0.7, tools: @prompt.actions)
        params = super

        # Add plugins if specified
        if @prompt.options[:plugins].present?
          params[:plugins] = @prompt.options[:plugins]
        end

        params
      end

      # Override to add plugins support for responses API
      def responses_parameters(model: @prompt.options[:model] || @model_name, messages: @prompt.messages, temperature: @prompt.options[:temperature] || @config["temperature"] || 0.7, tools: @prompt.actions, structured_output: @prompt.output_schema)
        params = super

        # Add plugins if specified
        if @prompt.options[:plugins].present?
          params[:plugins] = @prompt.options[:plugins]
        end

        params
      end
    end
  end
end

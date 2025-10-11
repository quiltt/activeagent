require_relative "_base_provider"

require_gem!(:openai, __FILE__)

require_relative "open_ai_provider"
require_relative "ollama/options"

module ActiveAgent
  module GenerationProvider
    class OllamaProvider < OpenAIProvider
      protected

      def namespace = Ollama
    end
  end
end

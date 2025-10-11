require "test_helper"
require "active_agent/generation_provider/open_router_provider"
require "active_agent/action_prompt/prompt"
require "active_agent/generation_provider/response"

module ActiveAgent
  module GenerationProvider
    class OllamaProviderTest < ActiveSupport::TestCase
      test "provider requires openai gem" do
        provider_file_path = File.join(Rails.root, "../../lib/active_agent/generation_provider/ollama_provider.rb")
        provider_source    = File.read(provider_file_path)

        assert_includes provider_source, "require_gem!(:openai, __FILE__)"
      end
    end
  end
end

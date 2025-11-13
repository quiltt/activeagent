# frozen_string_literal: true

require "active_agent/providers/common/model"

module ActiveAgent
  module Providers
    module Common
      # Common usage statistics model that normalizes token usage across all providers.
      #
      # This class provides a unified interface for accessing token usage and performance
      # metrics regardless of the underlying AI provider (OpenAI, Anthropic, Ollama, etc.).
      # Each provider returns usage data in different formats with different field names,
      # but this model normalizes them into a consistent structure.
      #
      # @note This model automatically calculates +total_tokens+ if not provided by the provider
      #
      # @example Accessing normalized usage data
      #   usage = response.normalized_usage
      #   usage.input_tokens      #=> 100
      #   usage.output_tokens     #=> 25
      #   usage.total_tokens      #=> 125
      #   usage.cached_tokens     #=> 20 (if available)
      #
      # @example Provider-specific details
      #   usage.provider_details  #=> { "completion_tokens_details" => {...}, ... }
      #   usage.duration_ms       #=> 5000 (for Ollama)
      #   usage.service_tier      #=> "standard" (for Anthropic)
      #
      # @see https://platform.openai.com/docs/api-reference/chat/object OpenAI Chat Completion
      # @see https://docs.anthropic.com/en/api/messages Anthropic Messages API
      # @see https://github.com/ollama/ollama/blob/main/docs/api.md Ollama API
      class Usage < BaseModel
        # @!attribute [rw] input_tokens
        #   Number of tokens in the input/prompt.
        #
        #   Normalized from:
        #   - OpenAI Chat/Embeddings: prompt_tokens
        #   - OpenAI Responses API: input_tokens
        #   - Anthropic: input_tokens
        #   - Ollama: prompt_eval_count
        #   - OpenRouter: prompt_tokens
        #
        #   @return [Integer] the number of input tokens
        attribute :input_tokens, :integer, default: 0

        # @!attribute [rw] output_tokens
        #   Number of tokens in the output/completion.
        #
        #   Normalized from:
        #   - OpenAI Chat: completion_tokens
        #   - OpenAI Responses API: output_tokens
        #   - Anthropic: output_tokens
        #   - Ollama: eval_count
        #   - OpenRouter: completion_tokens
        #   - OpenAI Embeddings: 0 (no output tokens)
        #
        #   @return [Integer] the number of output tokens
        attribute :output_tokens, :integer, default: 0

        # @!attribute [rw] total_tokens
        #   Total number of tokens used (input + output).
        #
        #   If not provided by the provider, this is automatically calculated
        #   as input_tokens + output_tokens.
        #
        #   @return [Integer] the total number of tokens
        attribute :total_tokens, :integer

        # @!attribute [rw] cached_tokens
        #   Number of tokens retrieved from cache (if supported by provider).
        #
        #   Available from:
        #   - OpenAI: prompt_tokens_details.cached_tokens or input_tokens_details.cached_tokens
        #   - Anthropic: cache_read_input_tokens
        #
        #   @return [Integer, nil] the number of cached tokens, or nil if not available
        attribute :cached_tokens, :integer

        # @!attribute [rw] reasoning_tokens
        #   Number of tokens used for reasoning/chain-of-thought (if supported).
        #
        #   Available from:
        #   - OpenAI Chat: completion_tokens_details.reasoning_tokens
        #   - OpenAI Responses: output_tokens_details.reasoning_tokens
        #
        #   @return [Integer, nil] the number of reasoning tokens, or nil if not available
        attribute :reasoning_tokens, :integer

        # @!attribute [rw] audio_tokens
        #   Number of tokens used for audio processing (if supported).
        #
        #   Available from:
        #   - OpenAI: sum of prompt_tokens_details.audio_tokens and completion_tokens_details.audio_tokens
        #
        #   @return [Integer, nil] the number of audio tokens, or nil if not available
        attribute :audio_tokens, :integer

        # @!attribute [rw] cache_creation_tokens
        #   Number of tokens used to create cache entries (if supported).
        #
        #   Available from:
        #   - Anthropic: cache_creation_input_tokens
        #
        #   @return [Integer, nil] the number of cache creation tokens, or nil if not available
        attribute :cache_creation_tokens, :integer

        # @!attribute [rw] service_tier
        #   Service tier used for the request (if provided by provider).
        #
        #   Available from:
        #   - Anthropic: service_tier ("standard", "priority", "batch")
        #
        #   @return [String, nil] the service tier, or nil if not available
        attribute :service_tier, :string

        # @!attribute [rw] duration_ms
        #   Total duration of the request in milliseconds (if provided by provider).
        #
        #   Available from:
        #   - Ollama: total_duration (converted from nanoseconds)
        #
        #   @return [Integer, nil] the duration in milliseconds, or nil if not available
        attribute :duration_ms, :integer

        # @!attribute [rw] provider_details
        #   Hash containing provider-specific metadata and additional fields.
        #
        #   This preserves all provider-specific information that doesn't fit
        #   into the normalized structure, allowing access to raw provider data
        #   when needed for debugging or provider-specific features.
        #
        #   @return [Hash] provider-specific metadata
        attribute :provider_details, default: -> { {} }

        # Initializes a new Usage object.
        #
        # If total_tokens is not provided, it will be automatically calculated
        # from input_tokens and output_tokens.
        #
        # @param attributes [Hash] usage attributes
        # @option attributes [Integer] :input_tokens number of input tokens
        # @option attributes [Integer] :output_tokens number of output tokens
        # @option attributes [Integer] :total_tokens total tokens (calculated if not provided)
        # @option attributes [Integer] :cached_tokens cached tokens
        # @option attributes [Integer] :reasoning_tokens reasoning tokens
        # @option attributes [Integer] :audio_tokens audio tokens
        # @option attributes [Integer] :cache_creation_tokens cache creation tokens
        # @option attributes [String] :service_tier service tier
        # @option attributes [Integer] :duration_ms duration in milliseconds
        # @option attributes [Hash] :provider_details provider-specific metadata
        #
        # @return [Usage] the initialized usage object
        def initialize(attributes = {})
          super
          # Calculate total_tokens if not provided
          self.total_tokens ||= (input_tokens || 0) + (output_tokens || 0)
        end

        # Creates a Usage object from OpenAI Chat Completion usage data.
        #
        # @param usage_hash [Hash] the OpenAI usage hash
        # @return [Usage] normalized usage object
        #
        # @example
        #   Usage.from_openai_chat({
        #     "prompt_tokens" => 100,
        #     "completion_tokens" => 25,
        #     "total_tokens" => 125,
        #     "prompt_tokens_details" => { "cached_tokens" => 20 },
        #     "completion_tokens_details" => { "reasoning_tokens" => 3 }
        #   })
        def self.from_openai_chat(usage_hash)
          return nil unless usage_hash

          usage = usage_hash.deep_symbolize_keys
          prompt_details = usage[:prompt_tokens_details] || {}
          completion_details = usage[:completion_tokens_details] || {}

          audio_sum = [
            prompt_details[:audio_tokens],
            completion_details[:audio_tokens]
          ].compact.sum

          new(
            **usage.slice(:total_tokens),
            input_tokens: usage[:prompt_tokens] || 0,
            output_tokens: usage[:completion_tokens] || 0,
            cached_tokens: prompt_details[:cached_tokens],
            reasoning_tokens: completion_details[:reasoning_tokens],
            audio_tokens: audio_sum > 0 ? audio_sum : nil,
            provider_details: usage.slice(:prompt_tokens_details, :completion_tokens_details).compact
          )
        end

        # Creates a Usage object from OpenAI Embedding API usage data.
        #
        # @param usage_hash [Hash] the OpenAI embedding usage hash
        # @return [Usage] normalized usage object
        #
        # @example
        #   Usage.from_openai_embedding({
        #     "prompt_tokens" => 8,
        #     "total_tokens" => 8
        #   })
        def self.from_openai_embedding(usage_hash)
          return nil unless usage_hash

          usage = usage_hash.deep_symbolize_keys

          new(
            **usage.slice(:total_tokens),
            input_tokens: usage[:prompt_tokens] || 0,
            output_tokens: 0, # Embeddings don't generate output tokens
            provider_details: usage.except(:prompt_tokens, :total_tokens)
          )
        end

        # Creates a Usage object from OpenAI Responses API usage data.
        #
        # @param usage_hash [Hash] the OpenAI responses usage hash
        # @return [Usage] normalized usage object
        #
        # @example
        #   Usage.from_openai_responses({
        #     "input_tokens" => 150,
        #     "output_tokens" => 75,
        #     "total_tokens" => 225,
        #     "input_tokens_details" => { "cached_tokens" => 50 },
        #     "output_tokens_details" => { "reasoning_tokens" => 10 }
        #   })
        def self.from_openai_responses(usage_hash)
          return nil unless usage_hash

          usage = usage_hash.deep_symbolize_keys
          input_details = usage[:input_tokens_details] || {}
          output_details = usage[:output_tokens_details] || {}

          new(
            **usage.slice(:input_tokens, :output_tokens, :total_tokens),
            input_tokens: usage[:input_tokens] || 0,
            output_tokens: usage[:output_tokens] || 0,
            cached_tokens: input_details[:cached_tokens],
            reasoning_tokens: output_details[:reasoning_tokens],
            provider_details: usage.slice(:input_tokens_details, :output_tokens_details).compact
          )
        end

        # Creates a Usage object from Anthropic usage data.
        #
        # @param usage_hash [Hash] the Anthropic usage hash
        # @return [Usage] normalized usage object
        #
        # @example
        #   Usage.from_anthropic({
        #     "input_tokens" => 2095,
        #     "output_tokens" => 503,
        #     "cache_read_input_tokens" => 1500,
        #     "cache_creation_input_tokens" => 2051,
        #     "service_tier" => "standard"
        #   })
        def self.from_anthropic(usage_hash)
          return nil unless usage_hash

          usage = usage_hash.deep_symbolize_keys

          new(
            **usage.slice(:input_tokens, :output_tokens, :service_tier),
            input_tokens: usage[:input_tokens] || 0,
            output_tokens: usage[:output_tokens] || 0,
            cached_tokens: usage[:cache_read_input_tokens],
            cache_creation_tokens: usage[:cache_creation_input_tokens],
            provider_details: usage.slice(:cache_creation, :server_tool_use).compact
          )
        end

        # Creates a Usage object from Ollama usage data.
        #
        # @param usage_hash [Hash] the Ollama usage hash
        # @return [Usage] normalized usage object
        #
        # @example
        #   Usage.from_ollama({
        #     "prompt_eval_count" => 50,
        #     "eval_count" => 25,
        #     "total_duration" => 5000000000,
        #     "load_duration" => 1000000000
        #   })
        def self.from_ollama(usage_hash)
          return nil unless usage_hash

          usage = usage_hash.deep_symbolize_keys

          new(
            input_tokens: usage[:prompt_eval_count] || 0,
            output_tokens: usage[:eval_count] || 0,
            duration_ms: convert_nanoseconds_to_ms(usage[:total_duration]),
            provider_details: {
              load_duration_ms: convert_nanoseconds_to_ms(usage[:load_duration]),
              prompt_eval_duration_ms: convert_nanoseconds_to_ms(usage[:prompt_eval_duration]),
              eval_duration_ms: convert_nanoseconds_to_ms(usage[:eval_duration]),
              tokens_per_second: calculate_tokens_per_second(usage[:eval_count], usage[:eval_duration])
            }.compact
          )
        end

        # Creates a Usage object from OpenRouter usage data.
        #
        # OpenRouter uses the same format as OpenAI Chat Completion.
        #
        # @param usage_hash [Hash] the OpenRouter usage hash
        # @return [Usage] normalized usage object
        #
        # @example
        #   Usage.from_openrouter({
        #     "prompt_tokens" => 14,
        #     "completion_tokens" => 4,
        #     "total_tokens" => 18
        #   })
        def self.from_openrouter(usage_hash)
          from_openai_chat(usage_hash)
        end

        # Auto-detects the provider format and creates a normalized Usage object.
        #
        # This method inspects the usage hash structure to determine which provider
        # format it matches and calls the appropriate factory method.
        #
        # @note Detection is based on hash structure rather than native gem types
        #   (e.g., Anthropic::Models::Message, OpenAI::Models::Chat::ChatCompletion)
        #   because we cannot force-load all provider gems. This allows the framework
        #   to work with only the gems the user has installed.
        #
        # @param usage_hash [Hash] the provider usage hash
        # @return [Usage, nil] normalized usage object, or nil if format unrecognized
        #
        # @example
        #   Usage.from_provider_usage(some_usage_hash)
        def self.from_provider_usage(usage_hash)
          return nil unless usage_hash.is_a?(Hash)

          usage = usage_hash.deep_symbolize_keys

          # Detect Ollama by presence of nanosecond duration fields
          if usage.key?(:total_duration)
            from_ollama(usage_hash)
          # Detect Anthropic by presence of cache_creation or service_tier
          elsif usage.key?(:cache_creation) || usage.key?(:service_tier)
            from_anthropic(usage_hash)
          # Detect OpenAI Responses API by input_tokens/output_tokens with details
          elsif usage.key?(:input_tokens) && usage.key?(:input_tokens_details)
            from_openai_responses(usage_hash)
          # Detect OpenAI Chat/OpenRouter by prompt_tokens/completion_tokens
          elsif usage.key?(:completion_tokens)
            from_openai_chat(usage_hash)
          # Detect OpenAI Embedding by prompt_tokens without completion_tokens
          elsif usage.key?(:prompt_tokens)
            from_openai_embedding(usage_hash)
          # Default to raw initialization
          else
            new(usage_hash)
          end
        end

        private

        # Converts nanoseconds to milliseconds.
        #
        # @param nanoseconds [Integer, nil] duration in nanoseconds
        # @return [Integer, nil] duration in milliseconds, or nil if input is nil
        def self.convert_nanoseconds_to_ms(nanoseconds)
          return nil unless nanoseconds

          (nanoseconds / 1_000_000.0).round
        end

        # Calculates tokens per second from token count and duration.
        #
        # @param tokens [Integer, nil] number of tokens
        # @param duration_ns [Integer, nil] duration in nanoseconds
        # @return [Float, nil] tokens per second, or nil if inputs are invalid
        def self.calculate_tokens_per_second(tokens, duration_ns)
          return nil unless tokens && duration_ns && duration_ns > 0

          (tokens.to_f / (duration_ns / 1_000_000_000.0)).round(2)
        end
      end
    end
  end
end

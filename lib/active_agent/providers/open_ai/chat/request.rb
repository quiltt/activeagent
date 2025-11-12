# frozen_string_literal: true

require "delegate"
require "json"
require_relative "transforms"

module ActiveAgent
  module Providers
    module OpenAI
      module Chat
        # Request wrapper that delegates to OpenAI gem model.
        #
        # Uses SimpleDelegator to wrap ::OpenAI::Models::Chat::CompletionCreateParams,
        # eliminating the need to maintain duplicate attribute definitions while
        # providing convenience transformations.
        #
        # All standard OpenAI Chat API fields are automatically available via delegation:
        # - model, messages, temperature, max_tokens, max_completion_tokens
        # - top_p, frequency_penalty, presence_penalty
        # - tools, tool_choice, response_format, stream_options
        # - audio, prediction, metadata, modalities
        # - service_tier, store, parallel_tool_calls, reasoning_effort, verbosity
        # - stop, seed, logit_bias, logprobs, top_logprobs
        # - prompt_cache_key, safety_identifier, user
        # - web_search_options
        # - function_call, functions (deprecated)
        #
        # @example Basic usage
        #   request = Request.new(
        #     model: "gpt-4o",
        #     messages: [{role: "user", content: "Hello"}]
        #   )
        #   request.model       #=> "gpt-4o"
        #   request.temperature #=> 1 (default)
        #
        # @example With transformations
        #   # String messages are automatically normalized
        #   request = Request.new(
        #     model: "gpt-4o",
        #     messages: "Hello"
        #   )
        #   # Internally becomes: [{role: "user", content: "Hello"}]
        #
        # @example Common format compatibility
        #   request = Request.new(
        #     model: "gpt-4o",
        #     messages: [{role: "user", content: "Hi"}],
        #     instructions: ["You are helpful", "Be concise"]
        #   )
        #   # instructions become developer messages
        class Request < SimpleDelegator
          # Default parameter values applied during initialization
          DEFAULTS = {
            frequency_penalty: 0,
            logprobs: false,
            modalities: [ "text" ],
            n: 1,
            parallel_tool_calls: true,
            presence_penalty: 0,
            service_tier: "auto",
            store: false,
            stream: false,
            temperature: 1,
            top_p: 1
          }.freeze

          # @return [Boolean, nil]
          attr_reader :stream

          # Initializes request with field mapping and normalization.
          #
          # Maps common format fields (instructions) and normalizes messages.
          #
          # @param params [Hash]
          # @option params [String] :model required
          # @option params [Array, String, Hash] :messages required
          # @option params [Array<String>, String] :instructions system/developer prompts
          # @option params [Hash, String, Symbol] :response_format
          # @raise [ArgumentError] when gem model initialization fails
          def initialize(**params)
            # Extract stream flag
            @stream = params[:stream]

            # Apply defaults
            params = apply_defaults(params)

            # Normalize all parameters (instructions, messages, response_format)
            params = Chat::Transforms.normalize_params(params)

            # Create gem model - this validates all parameters!
            gem_model = ::OpenAI::Models::Chat::CompletionCreateParams.new(**params)

            # Delegate all method calls to gem model
            super(gem_model)
          rescue ArgumentError => e
            # Re-raise with more context
            raise ArgumentError, "Invalid OpenAI Chat request parameters: #{e.message}"
          end

          # Serializes request for API call.
          #
          # Uses gem's JSON serialization, removes default values to keep request
          # body minimal, and simplifies messages where possible.
          #
          # @return [Hash]
          def serialize
            # Use gem's JSON serialization (handles all nested objects)
            hash = Chat::Transforms.gem_to_hash(__getobj__)

            # Cleanup and simplify for API request
            Chat::Transforms.cleanup_serialized_request(hash, DEFAULTS, __getobj__)
          end

          # Accessor for messages.
          #
          # @return [Array<Hash>, nil]
          def messages
            __getobj__.instance_variable_get(:@data)[:messages]
          end

          # Sets messages with normalization.
          #
          # @param value [Array, String, Hash]
          # @return [void]
          def messages=(value)
            normalized_value = Chat::Transforms.normalize_messages(value)
            __getobj__.instance_variable_get(:@data)[:messages] = normalized_value
          end

          # Alias for messages (common format compatibility).
          #
          # @return [Array<Hash>, nil]
          def message
            messages
          end

          # @param value [Array, String, Hash]
          def message=(value)
            self.messages = value
          end

          # Sets instructions as developer messages (common format compatibility).
          #
          # Prepends developer messages to the messages array.
          #
          # @param values [Array<String>, String]
          # @return [void]
          def instructions=(*values)
            instructions_messages = Chat::Transforms.normalize_instructions(values.flatten)
            current_messages = messages || []
            self.messages = instructions_messages + current_messages
          end

          private

          # @api private
          # @param params [Hash]
          # @return [Hash]
          def apply_defaults(params)
            # Only apply defaults for keys that aren't present
            DEFAULTS.each do |key, value|
              params[key] = value unless params.key?(key)
            end

            params
          end
        end
      end
    end
  end
end

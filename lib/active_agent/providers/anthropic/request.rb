# frozen_string_literal: true

require "delegate"
require "json"
require_relative "transforms"

module ActiveAgent
  module Providers
    module Anthropic
      # Request wrapper that delegates to Anthropic gem model.
      #
      # Uses SimpleDelegator to wrap ::Anthropic::Models::MessageCreateParams,
      # eliminating the need to maintain duplicate attribute definitions while
      # providing convenience transformations and custom fields.
      #
      # All standard Anthropic API fields are automatically available via delegation:
      # - model, messages, max_tokens
      # - system, temperature, top_k, top_p, stop_sequences
      # - tools, tool_choice, thinking
      # - stream, metadata, context_management, container, service_tier, mcp_servers
      #
      # Custom fields managed separately:
      # - response_format (simulated JSON mode feature)
      #
      # @example Basic usage
      #   request = Request.new(
      #     model: "claude-3-5-haiku-latest",
      #     messages: [{role: "user", content: "Hello"}]
      #   )
      #   request.model      #=> "claude-3-5-haiku-latest"
      #   request.max_tokens #=> 4096 (default)
      #
      # @example With transformations
      #   # String content is automatically normalized
      #   request = Request.new(
      #     model: "...",
      #     messages: [{role: "user", content: "Hi"}]
      #   )
      #   # Internally becomes: [{type: "text", text: "Hi"}]
      #
      # @example Custom field
      #   request = Request.new(
      #     model: "...",
      #     messages: [...],
      #     response_format: {type: "json_object"}
      #   )
      #   request.response_format #=> {type: "json_object"}
      class Request < SimpleDelegator
        # Default max_tokens value when not specified
        DEFAULT_MAX_TOKENS = 4096

        # Default values for optional parameters
        DEFAULTS = {
          max_tokens: DEFAULT_MAX_TOKENS,
          stop_sequences: [],
          mcp_servers: []
        }.freeze

        # @return [Hash, nil] simulated JSON response format configuration
        attr_reader :response_format

        # @return [Boolean, nil] whether to stream the response
        attr_reader :stream

        # @param params [Hash]
        # @option params [String] :model required
        # @option params [Array<Hash>] :messages required
        # @option params [Integer] :max_tokens (4096)
        # @option params [Hash] :response_format custom field for JSON mode simulation
        # @raise [ArgumentError] when gem model validation fails
        def initialize(**params)
          # Extract custom fields that gem doesn't support
          @response_format = params.delete(:response_format)
          @stream = params.delete(:stream)

          # Map common format 'instructions' to Anthropic's 'system'
          if params.key?(:instructions)
            params[:system] = params.delete(:instructions)
          end

          # Apply defaults
          params = apply_defaults(params)

          # Transform params for gem compatibility
          transformed = Transforms.normalize_params(params)

          # Create gem model - this validates all parameters!
          gem_model = ::Anthropic::Models::MessageCreateParams.new(**transformed)

          # Delegate all method calls to gem model
          super(gem_model)
        rescue ArgumentError => e
          # Re-raise with more context
          raise ArgumentError, "Invalid Anthropic request parameters: #{e.message}"
        end

        # Serializes request for API call with content compression.
        #
        # Uses gem's JSON serialization, then removes response-only fields
        # and compresses single text blocks to string shorthand for efficiency.
        #
        # @return [Hash]
        def serialize
          # Use gem's JSON serialization (handles all nested objects)
          hash = Anthropic::Transforms.gem_to_hash(__getobj__)

          # Clean up messages - remove response-only fields
          if hash[:messages]
            hash[:messages].each do |msg|
              msg.delete(:id)
              msg.delete(:model)
              msg.delete(:stop_reason)
              msg.delete(:stop_sequence)
              msg.delete(:type)
              msg.delete(:usage)
            end
          end

          # Apply content compression for API efficiency
          Transforms.compress_content(hash)

          # Remove provider-internal fields that should not be in API request
          hash.delete(:mcp_servers)   # Provider-level config, not API param
          hash.delete(:stop_sequences) if hash[:stop_sequences] == []

          hash
        end

        # Accessor for system instructions.
        #
        # Must override SimpleDelegator's method_missing because Ruby's Kernel.system
        # conflicts with delegation. The gem stores data in @data instance variable.
        #
        # @return [String, Array, nil]
        def system
          __getobj__.instance_variable_get(:@data)[:system]
        end

        # @param value [String, Array]
        def system=(value)
          __getobj__.instance_variable_get(:@data)[:system] = value
        end

        # Alias for system (common format compatibility).
        #
        # @return [String, Array, nil]
        def instructions
          system
        end

        # @param value [String, Array]
        def instructions=(value)
          self.system = value
        end

        # Removes the last message from the messages array.
        #
        # Used for JSON format simulation to remove the lead-in assistant message.
        #
        # @return [void]
        def pop_message!
          new_messages = messages.dup
          new_messages.pop
          self.messages = new_messages
        end

        private

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

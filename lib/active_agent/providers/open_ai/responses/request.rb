# frozen_string_literal: true

require_relative "transforms"

module ActiveAgent
  module Providers
    module OpenAI
      module Responses
        # Wraps OpenAI Responses API request parameters with field mapping and normalization.
        #
        # Uses SimpleDelegator to delegate to OpenAI::Models::Responses::ResponseCreateParams
        # while providing compatibility layer for common format fields (messages→input,
        # response_format→text) and content normalization.
        class Request < SimpleDelegator
          # Default parameter values applied during initialization
          DEFAULTS = {
            service_tier: "auto",
            store: true,
            temperature: 1.0,
            top_p: 1.0,
            truncation: "disabled",
            parallel_tool_calls: true,
            background: false,
            include: []
          }.freeze

          # @return [Boolean, nil]
          attr_reader :stream

          # @return [Hash, nil]
          attr_reader :response_format

          # Initializes request with field mapping and normalization.
          #
          # Maps common format fields to Responses API format:
          # - messages → input
          # - response_format → text (via ResponseTextConfig)
          # - instructions array joined to string
          #
          # @param params [Hash]
          # @option params [String] :model
          # @option params [Array, String, Hash] :input messages or content
          # @option params [Array, String, Hash] :messages alternative to :input
          # @option params [Hash, String, Symbol] :response_format
          # @option params [Array<String>, String] :instructions
          # @option params [Integer] :max_output_tokens
          # @raise [ArgumentError] when gem model initialization fails
          def initialize(**params)
            # Extract custom fields
            @stream = params[:stream]
            @response_format = params.delete(:response_format)

            # Map common format 'messages' to OpenAI Responses 'input'
            if params.key?(:messages)
              params[:input] = params.delete(:messages)
            end

            # Join instructions array into string (like Chat API)
            if params[:instructions].is_a?(Array)
              params[:instructions] = params[:instructions].join("\n")
            end

            # Map response_format to text parameter for Responses API
            if @response_format
              params[:text] = Responses::Transforms.normalize_response_format(@response_format)
            end

            # Apply defaults
            params = apply_defaults(params)

            # Normalize input content for gem compatibility
            params[:input] = Responses::Transforms.normalize_input(params[:input]) if params[:input]

            # Create gem model - delegates to OpenAI gem
            gem_model = ::OpenAI::Models::Responses::ResponseCreateParams.new(**params)

            # Delegate all method calls to gem model
            super(gem_model)
          rescue ArgumentError => e
            # Re-raise with more context
            raise ArgumentError, "Invalid OpenAI Responses request parameters: #{e.message}"
          end

          # Serializes request for API call.
          #
          # Removes default values to keep request body minimal and simplifies
          # single-element input arrays to strings where possible.
          #
          # @return [Hash]
          def serialize
            hash = Responses::Transforms.gem_to_hash(__getobj__)

            # Remove default values that shouldn't be in the request body
            DEFAULTS.each do |key, value|
              hash.delete(key) if hash[key] == value
            end

            # Simplify input when possible for cleaner API requests
            hash[:input] = Responses::Transforms.simplify_input(hash[:input]) if hash[:input]

            hash
          end

          # @return [Array, String, Hash, nil]
          def messages
            __getobj__.instance_variable_get(:@data)[:input]
          end

          # Sets input messages with normalization.
          #
          # Converts strings to message objects and ensures proper format.
          #
          # @param value [Array, String, Hash]
          # @return [void]
          def messages=(value)
            normalized_value = Responses::Transforms.normalize_input(value)
            __getobj__.instance_variable_get(:@data)[:input] = normalized_value
          end

          alias_method :message, :messages
          alias_method :message=, :messages=

          private

          # @api private
          # @param params [Hash]
          # @return [Hash]
          def apply_defaults(params)
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

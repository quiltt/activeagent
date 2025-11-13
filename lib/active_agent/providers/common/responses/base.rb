# frozen_string_literal: true

require "active_agent/providers/common/model"
require "active_agent/providers/common/usage"

module ActiveAgent
  module Providers
    module Common
      module Responses
        # Base response model for provider responses.
        #
        # This class represents the standard response structure from AI providers
        # across different services (OpenAI, Anthropic, etc.). It provides a unified
        # interface for accessing response data, usage statistics, and request context.
        #
        # @abstract Subclass and override {#usage} if provider uses non-standard format
        #
        # @note This is a base class. Use specialized subclasses for specific response types:
        #   - {Prompt} for conversational/completion responses with messages
        #   - {Embed} for embedding responses with vector data
        #
        # @example Accessing response data
        #   response = agent.prompt.generate_now
        #   response.success?         #=> true
        #   response.usage            #=> Usage object with normalized fields
        #   response.total_tokens     #=> 30
        #
        # @example Inspecting raw provider data
        #   response.raw_request      #=> { "model" => "gpt-4", "messages" => [...] }
        #   response.raw_response     #=> { "id" => "chatcmpl-...", "choices" => [...] }
        #
        # @see Prompt
        # @see Embed
        # @see BaseModel
        class Base < BaseModel
          # @!attribute [r] context
          #   The original context that was sent to the provider.
          #
          #   Contains structured information about the request including instructions,
          #   messages, tools, and other configuration passed to the LLM.
          #
          #   @return [Hash] the request context
          attribute :context, writable: false

          # @!attribute [r] raw_request
          #   The most recent request in provider-specific format.
          #
          #   Contains the actual API request payload sent to the provider,
          #   useful for debugging and logging.
          #
          #   @return [Hash] the provider-formatted request
          attribute :raw_request, writable: false

          # @!attribute [r] raw_response
          #   The most recent response in provider-specific format.
          #
          #   Contains the raw API response from the provider, including all
          #   metadata, usage stats, and provider-specific fields.
          #
          #   Note: Hash keys are automatically deep symbolized for consistent access.
          #
          #   @return [Hash] the provider-formatted response with symbolized keys
          attribute :raw_response, writable: false

          # Initializes a new response object with deep-duplicated attributes.
          #
          # Deep duplication ensures that the response object maintains its own
          # independent copy of the data, preventing external modifications from
          # affecting the response's internal state.
          #
          # Additionally, raw_response is deep symbolized for consistent key access
          # across all providers.
          #
          # @param kwargs [Hash] response attributes
          # @option kwargs [Hash] :context the original request context
          # @option kwargs [Hash] :raw_request the provider-formatted request
          # @option kwargs [Hash] :raw_response the provider-formatted response
          #
          # @return [Base] the initialized response object
          def initialize(kwargs = {})
            kwargs = kwargs.deep_dup # Ensure that userland can't fuck with our memory space

            # Deep symbolize raw_response for consistent access across all extraction methods
            if kwargs[:raw_response].is_a?(Hash)
              kwargs[:raw_response] = kwargs[:raw_response].deep_symbolize_keys
            end

            super(kwargs)
          end

          # Extracts instructions from the context.
          #
          # @return [String, Array<Hash>, nil] the instructions that were sent to the provider
          def instructions
            context[:instructions]
          end

          # Indicates whether the generation request was successful.
          #
          # @todo Better handling of failure flows
          #
          # @return [Boolean] true if successful, false otherwise
          def success?
            true
          end

          # Returns normalized usage statistics across all providers.
          #
          # This method provides a consistent interface for accessing token usage
          # regardless of the underlying provider. It automatically detects the
          # provider format and returns a {Usage} object with normalized fields.
          #
          # @return [Usage, nil] normalized usage object, or nil if not available
          #
          # @example Accessing normalized usage
          #   response.usage.input_tokens      #=> 100
          #   response.usage.output_tokens     #=> 25
          #   response.usage.total_tokens      #=> 125
          #   response.usage.cached_tokens     #=> 20 (if available)
          #
          # @see Usage
          def usage
            @usage ||= begin
              return nil unless raw_response

              # Extract raw usage hash from provider response
              raw_usage = raw_response[:usage] if raw_response.is_a?(Hash)

              Usage.from_provider_usage(raw_usage)
            end
          end

          # Returns the response ID from the provider.
          #
          # All providers (OpenAI, Anthropic, Ollama, OpenRouter) return unique
          # identifiers for their responses, useful for tracking and debugging.
          #
          # @return [String, nil] the response ID, or nil if not available
          #
          # @example Accessing response ID
          #   response.id  #=> "chatcmpl-CbDx1nXoNSBrNIMhiuy5fk7jXQjmT" (OpenAI)
          #   response.id  #=> "msg_01RotDmSnYpKQjrTpaHUaEBz" (Anthropic)
          #   response.id  #=> "gen-1761505659-yxgaVsqVABMQqw6oA7QF" (OpenRouter)
          def id
            @id ||= begin
              return nil unless raw_response

              if raw_response.is_a?(Hash)
                raw_response[:id]
              elsif raw_response.respond_to?(:id)
                raw_response.id
              end
            end
          end

          # Returns the model name from the provider response.
          #
          # Useful for confirming which model was actually used, as providers may
          # use different model versions than requested.
          #
          # @return [String, nil] the model name, or nil if not available
          #
          # @example Accessing response model
          #   response.model  #=> "gpt-4o-mini-2024-07-18"
          #   response.model  #=> "claude-3-5-haiku-20241022"
          def model
            @model ||= begin
              return nil unless raw_response

              if raw_response.is_a?(Hash)
                raw_response[:model]
              elsif raw_response.respond_to?(:model)
                raw_response.model
              end
            end
          end

          # Returns the finish reason from the provider response.
          #
          # Indicates why the generation stopped (e.g., "stop", "length", "tool_calls").
          # Different providers use different field names but this method normalizes access.
          #
          # @return [String, nil] the finish reason, or nil if not available
          #
          # @example Accessing finish reason
          #   response.finish_reason  #=> "stop"
          #   response.finish_reason  #=> "length"
          #   response.finish_reason  #=> "tool_calls"
          #   response.stop_reason    #=> "stop" (alias)
          def finish_reason
            @finish_reason ||= begin
              return nil unless raw_response

              if raw_response.is_a?(Hash)
                # OpenAI format: choices[0].finish_reason or choices[0].message.finish_reason
                raw_response.dig(:choices, 0, :finish_reason) ||
                  raw_response.dig(:choices, 0, :message, :finish_reason) ||
                  # Anthropic format: stop_reason
                  raw_response[:stop_reason]
              end
            end
          end
          alias_method :stop_reason, :finish_reason
        end
      end
    end
  end
end

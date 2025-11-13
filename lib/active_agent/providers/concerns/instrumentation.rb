# frozen_string_literal: true

module ActiveAgent
  module Providers
    # Builds instrumentation event payloads for ActiveSupport::Notifications.
    #
    # Extracts request parameters and response metadata for monitoring, debugging,
    # and APM integration (New Relic, DataDog, etc.).
    #
    # == Event Payloads
    #
    # prompt_start.provider.active_agent::
    #   `{ model:, temperature:, max_tokens:, message_count:, has_tools:, stream: }`
    #
    # prompt_complete.provider.active_agent::
    #   `{ usage: { input_tokens:, output_tokens:, total_tokens: }, finish_reason:, response_model:, response_id: }`
    #
    # embed_start.provider.active_agent::
    #   `{ model:, input_size:, encoding_format:, dimensions: }`
    #
    # embed_complete.provider.active_agent::
    #   `{ usage: { input_tokens:, total_tokens: }, embedding_count:, response_model:, response_id: }`
    #
    # @see BaseProvider
    module Instrumentation
      extend ActiveSupport::Concern

      # Builds payload for prompt_start event.
      #
      # Called at the start of prompt requests to capture parameters for correlation
      # with completion events. Usage data is critical for APM cost tracking.
      #
      # @return [Hash] payload with model, temperature, max_tokens, top_p, message_count, has_tools, has_instructions, stream
      def instrumentation_prompt_start_payload
        payload = {
          message_count: request.messages&.size || 0,
          stream: !!request.stream
        }

        # Add common parameters if available
        payload[:model]       = request.model       if request.respond_to?(:model)
        payload[:temperature] = request.temperature if request.respond_to?(:temperature)
        payload[:max_tokens]  = request.max_tokens  if request.respond_to?(:max_tokens)
        payload[:top_p]       = request.top_p       if request.respond_to?(:top_p)

        # Add tool information
        if request.respond_to?(:tools)
          payload[:has_tools]  = request.tools.present?
          payload[:tool_count] = request.tools&.size || 0
        end

        # Add instructions indicator if available
        if request.respond_to?(:instructions)
          payload[:has_instructions] = request.instructions.present?
        end

        payload
      end

      # Builds payload for prompt_complete event.
      #
      # Called after response is received. Extracts normalized usage data from the
      # response model, ensuring consistency across all providers (OpenAI, Anthropic, etc.).
      #
      # Usage data (tokens) is CRITICAL for APM cost tracking and performance monitoring.
      #
      # @param response [Common::PromptResponse] completed response with normalized data
      # @return [Hash] payload with usage (input/output/total/cached tokens), finish_reason, response_model, response_id, message_count
      def instrumentation_prompt_complete_payload(response)
        payload = {
          message_count: message_stack.size
        }

        # Add usage data if available (CRITICAL for APM integration)
        # The Usage object already normalizes token counts across all providers
        if response.usage
          payload[:usage] = {
            input_tokens: response.usage.input_tokens,
            output_tokens: response.usage.output_tokens,
            total_tokens: response.usage.total_tokens
          }
          # Add cached tokens if available (for providers that support prompt caching)
          payload[:usage][:cached_tokens] = response.usage.cached_tokens if response.usage.cached_tokens
        end

        # Add response metadata directly from response object
        # The response model provides normalized access across all providers
        payload[:finish_reason]  = response.finish_reason
        payload[:response_model] = response.model
        payload[:response_id]    = response.id

        payload
      end

      # Builds payload for embed_start event.
      #
      # Called at the start of embedding requests to capture parameters for correlation
      # with completion events.
      #
      # @return [Hash] payload with model, input_size, encoding_format, dimensions
      def instrumentation_embed_start_payload
        payload = {}

        # Add model if available
        payload[:model] = request.model if request.respond_to?(:model)

        # Add input size if available
        if request.respond_to?(:input)
          begin
            input = request.input
            if input.is_a?(String)
              payload[:input_size] = 1
            elsif input.is_a?(Array)
              payload[:input_size] = input.size
            end
          rescue
            # If accessing input fails (e.g., due to OpenAI gem type conversion),
            # skip the input_size field
          end
        end

        # Add encoding format if available (OpenAI)
        payload[:encoding_format] = request.encoding_format if request.respond_to?(:encoding_format)

        # Add dimensions if available (OpenAI)
        payload[:dimensions] = request.dimensions if request.respond_to?(:dimensions)

        payload
      end

      # Builds payload for embed_complete event.
      #
      # Called after embedding response is received. Extracts normalized usage data,
      # ensuring consistency across all providers.
      #
      # Embeddings typically only report input tokens (no output tokens).
      #
      # @param response [Common::EmbedResponse] completed response with normalized data
      # @return [Hash] payload with usage (input/total tokens), embedding_count, response_model, response_id
      def instrumentation_embed_complete_payload(response)
        payload = {}

        # Add embedding count
        payload[:embedding_count] = response.data&.size || 0

        # Add usage data if available (CRITICAL for APM integration)
        # Embeddings typically only have input tokens
        if response.usage
          payload[:usage] = {
            input_tokens: response.usage.input_tokens,
            total_tokens: response.usage.total_tokens
          }
        end

        # Add response metadata directly from response object
        payload[:response_model] = response.model
        payload[:response_id]    = response.id

        payload
      end
    end
  end
end

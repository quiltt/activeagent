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
    # Top-Level Events (overall request lifecycle):
    #
    # prompt.active_agent::
    #   Initial: `{ model:, temperature:, max_tokens:, message_count:, has_tools:, stream: }`
    #   Final: `{ usage: { input_tokens:, output_tokens:, total_tokens: }, finish_reason:, response_model:, response_id: }`
    #   Note: Usage is cumulative across all API calls in multi-turn conversations
    #
    # embed.active_agent::
    #   Initial: `{ model:, input_size:, encoding_format:, dimensions: }`
    #   Final: `{ usage: { input_tokens:, total_tokens: }, embedding_count:, response_model:, response_id: }`
    #
    # Provider-Level Events (per API call):
    #
    # prompt.provider.active_agent::
    #   Initial: `{ model:, temperature:, max_tokens:, message_count:, has_tools:, stream: }`
    #   Final: `{ usage: { input_tokens:, output_tokens:, total_tokens: }, finish_reason:, response_model:, response_id: }`
    #   Note: Usage is per individual API call
    #
    # embed.provider.active_agent::
    #   Initial: `{ model:, input_size:, encoding_format:, dimensions: }`
    #   Final: `{ usage: { input_tokens:, total_tokens: }, embedding_count:, response_model:, response_id: }`
    module Instrumentation
      extend ActiveSupport::Concern

      # Builds and merges payload data for prompt instrumentation events.
      #
      # Populates both request parameters and response metadata for top-level and
      # provider-level events. Usage data (tokens) is CRITICAL for APM cost tracking
      # and performance monitoring.
      #
      # @param payload [Hash] instrumentation payload to merge into
      # @param request [Request] request object with parameters
      # @param response [Common::PromptResponse] completed response with normalized data
      # @return [void]
      def instrumentation_prompt_payload(payload, request, response)
        # Add request parameters
        payload.merge!(
          trace_id: trace_id,
          message_count: request.messages&.size || 0,
          stream: !!request.stream
        )

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

        # Add usage data if available (CRITICAL for APM integration)
        # The Usage object already normalizes token counts across all providers
        if response.usage
          payload[:usage] = {
            input_tokens:  response.usage.input_tokens,
            output_tokens: response.usage.output_tokens,
            total_tokens:  response.usage.total_tokens
          }
          # Add all available usage tokens (cached, reasoning, audio, etc.)
          payload[:usage][:cached_tokens]         = response.usage.cached_tokens         if response.usage.cached_tokens
          payload[:usage][:cache_creation_tokens] = response.usage.cache_creation_tokens if response.usage.cache_creation_tokens
          payload[:usage][:reasoning_tokens]      = response.usage.reasoning_tokens      if response.usage.reasoning_tokens
          payload[:usage][:audio_tokens]          = response.usage.audio_tokens          if response.usage.audio_tokens
        end

        # Add response metadata directly from response object
        # The response model provides normalized access across all providers
        payload[:finish_reason]  = response.finish_reason
        payload[:response_model] = response.model
        payload[:response_id]    = response.id
      end

      # Builds and merges payload data for embed instrumentation events.
      #
      # Embeddings typically only report input tokens (no output tokens).
      #
      # @param payload [Hash] instrumentation payload to merge into
      # @param request [Request] request object with parameters
      # @param response [Common::EmbedResponse] completed response with normalized data
      # @return [void]
      def instrumentation_embed_payload(payload, request, response)
        # Add request parameters
        payload[:trace_id] = trace_id
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
          rescue # OpenAI throws errors this for some reason when you try to look at the input.
            payload[:input_size] = request[:input].size
          end
        end

        # Add encoding format if available (OpenAI)
        payload[:encoding_format] = request.encoding_format if request.respond_to?(:encoding_format)

        # Add dimensions if available (OpenAI)
        payload[:dimensions] = request.dimensions if request.respond_to?(:dimensions)

        # Add response data
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
      end
    end
  end
end

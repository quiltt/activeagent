# frozen_string_literal: true

require "json"
require_relative "transforms"

module ActiveAgent
  module Providers
    module OpenAI
      module Embedding
        # Wraps OpenAI gem's EmbeddingCreateParams with normalization
        #
        # Delegates to OpenAI::Models::EmbeddingCreateParams while providing
        # parameter normalization via the Transforms module
        class Request < SimpleDelegator
          # Creates a new embedding request
          #
          # @param params [Hash] embedding parameters
          # @option params [String, Array<String>, Array<Integer>, Array<Array<Integer>>] :input
          #   text or token array(s) to embed
          # @option params [String] :model embedding model identifier
          # @option params [Integer, nil] :dimensions number of dimensions for output (text-embedding-3 only)
          # @option params [String, nil] :encoding_format "float" or "base64"
          # @option params [String, nil] :user unique user identifier
          def initialize(params = {})
            normalized_params = Transforms.normalize_params(params)
            gem_model = ::OpenAI::Models::EmbeddingCreateParams.new(**normalized_params)
            super(gem_model)
          end

          # Serializes request for API submission
          #
          # @return [Hash] cleaned request hash without nil values
          def serialize
            serialized = Transforms.gem_to_hash(__getobj__)
            Transforms.cleanup_serialized_request(serialized)
          end
        end
      end
    end
  end
end

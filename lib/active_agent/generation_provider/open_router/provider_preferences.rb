# frozen_string_literal: true

module ActiveAgent
  module GenerationProvider
    module OpenRouter
      # Provider preferences for routing requests to specific providers
      # See: https://openrouter.ai/docs/provider-routing
      class ProviderPreferences
        include ActiveModel::Model
        include ActiveModel::Attributes

        # Allow using fallback providers if primary providers fail
        attribute :allow_fallbacks, :boolean, default: true

        # Require specific parameters to be supported by the provider
        attribute :require_parameters, :boolean

        # Control whether data can be used for training
        # Options: 'deny', 'allow'
        attribute :data_collection, :string

        # Ordered list of provider names to try (e.g., ['OpenAI', 'Anthropic'])
        attribute :order, default: -> { [] }

        # List of quantization levels (e.g., ['int4', 'int8'])
        attribute :quantizations, default: -> { [] }

        # List of provider names to ignore/exclude
        attribute :ignore, default: -> { [] }

        validates :data_collection, inclusion: { in: %w[deny allow] }, allow_nil: true

        # Backwards Compatibility
        alias_attribute :enable_fallbacks, :allow_fallbacks

        def to_h
          {
            allow_fallbacks:,
            require_parameters:,
            data_collection:,
            order:,
            quantizations:,
            ignore:
          }.compact
        end

        alias_method :to_hash, :to_h
      end
    end
  end
end

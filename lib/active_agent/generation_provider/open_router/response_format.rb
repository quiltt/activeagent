# frozen_string_literal: true

module ActiveAgent
  module GenerationProvider
    module OpenRouter
      class ResponseFormat
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :type, :string

        validates :type, inclusion: { in: %w[json_object] }, allow_nil: true

        def to_h
          { type: }.compact
        end

        alias_method :to_hash, :to_h
      end
    end
  end
end

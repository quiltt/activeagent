# frozen_string_literal: true

module ActiveAgent
  module GenerationProvider
    module OpenRouter
      class Prediction
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :type, :string
        attribute :content, :string

        validates :type, inclusion: { in: %w[content] }, allow_nil: true
        validates :content, presence: true, if: -> { type.present? }

        def to_h
          { type:, content: }.compact
        end

        alias_method :to_hash, :to_h
      end
    end
  end
end

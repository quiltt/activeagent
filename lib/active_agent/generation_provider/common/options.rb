# frozen_string_literal: true

module ActiveAgent
  module GenerationProvider
    module Common
      class Options
        include ActiveModel::Model
        include ActiveModel::Attributes

        def self.delegate_attributes(*attributes, to:)
          attributes.each do |attribute|
            define_method(attribute) do
              public_send(to)&.public_send(attribute)
            end

            define_method("#{attribute}=") do |value|
              if public_send(to).nil?
                public_send("#{to}=", {})
              end

              public_send(to).public_send("#{attribute}=", value)
            end
          end
        end

          def deep_compact(hash = nil, **kwargs)
            (hash || kwargs).each_with_object({}) do |(key, value), result|
              compacted_value = case value
              when Hash
                deep_compacted = deep_compact(value)
                deep_compacted unless deep_compacted.empty?
              when Array
                compacted_array = value.map { |v| v.is_a?(Hash) ? deep_compact(v) : v }.compact
                compacted_array unless compacted_array.empty?
              else
                value
              end

              result[key] = compacted_value unless compacted_value.nil?
            end
          end
      end
    end
  end
end

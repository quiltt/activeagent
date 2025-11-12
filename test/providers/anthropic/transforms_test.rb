# frozen_string_literal: true

require "test_helper"
require "active_agent/providers/anthropic/transforms"

module ActiveAgent
  module Providers
    module Anthropic
      class TransformsTest < ActiveSupport::TestCase
        test ".normalize_params passes through unchanged params" do
          params = { model: "claude-3", messages: [] }
          result = Transforms.normalize_params(params)

          assert_equal "claude-3", result[:model]
          assert_equal [], result[:messages]
        end

        test ".normalize_params normalizes messages" do
          params = {
            model: "claude-3",
            messages: [ { role: "user", content: "Hello" } ]
          }

          result = Transforms.normalize_params(params)

          assert_equal 1, result[:messages].length
          assert_equal :user, result[:messages].first[:role]
          assert_equal [ { type: "text", text: "Hello" } ], result[:messages].first[:content]
        end

        test ".normalize_params normalizes system" do
          params = {
            model: "claude-3",
            messages: [],
            system: "You are helpful"
          }

          result = Transforms.normalize_params(params)

          assert_equal "You are helpful", result[:system]
        end

        test ".normalize_messages handles empty array" do
          result = Transforms.normalize_messages([])
          assert_equal [], result
        end

        test ".normalize_messages handles nil" do
          result = Transforms.normalize_messages(nil)
          assert_nil result
        end

        test ".normalize_messages converts string content to structured format" do
          messages = [ { role: "user", content: "Hello" } ]
          result = Transforms.normalize_messages(messages)

          assert_equal 1, result.length
          assert_equal :user, result.first[:role]
          assert_equal [ { type: "text", text: "Hello" } ], result.first[:content]
        end

        test ".normalize_messages groups consecutive same-role messages" do
          messages = [
            { role: "user", content: "First" },
            { role: "user", content: "Second" },
            { role: "assistant", content: "Response" }
          ]

          result = Transforms.normalize_messages(messages)

          assert_equal 2, result.length
          assert_equal :user, result.first[:role]
          assert_equal 2, result.first[:content].length
          assert_equal "First", result.first[:content][0][:text]
          assert_equal "Second", result.first[:content][1][:text]
        end

        test ".normalize_messages handles alternating roles" do
          messages = [
            { role: "user", content: "Question" },
            { role: "assistant", content: "Answer" },
            { role: "user", content: "Follow-up" }
          ]

          result = Transforms.normalize_messages(messages)

          assert_equal 3, result.length
        end

        test ".normalize_messages defaults to user role when missing" do
          messages = [ { content: "Hello" } ]
          result = Transforms.normalize_messages(messages)

          assert_equal :user, result.first[:role]
        end

        test ".normalize_system keeps strings as-is" do
          result = Transforms.normalize_system("You are helpful")
          assert_equal "You are helpful", result
        end

        test ".normalize_system handles array of strings" do
          system = [ "First instruction", "Second instruction" ]
          result = Transforms.normalize_system(system)

          assert_equal 2, result.length
          assert_equal({ type: "text", text: "First instruction" }, result[0])
          assert_equal({ type: "text", text: "Second instruction" }, result[1])
        end

        test ".normalize_system handles hash" do
          system = { text: "You are helpful" }
          result = Transforms.normalize_system(system)

          assert_equal 1, result.length
          assert_equal({ type: "text", text: "You are helpful" }, result[0])
        end

        test ".normalize_content converts string to text block" do
          result = Transforms.normalize_content("Hello")

          assert_equal 1, result.length
          assert_equal({ type: "text", text: "Hello" }, result[0])
        end

        test ".normalize_content handles array" do
          content = [
            { type: "text", text: "Hello" },
            { type: "text", text: "World" }
          ]

          result = Transforms.normalize_content(content)

          assert_equal 2, result.length
        end

        test ".normalize_content handles nil" do
          result = Transforms.normalize_content(nil)
          assert_equal [], result
        end

        test ".normalize_content_item adds type to text hash" do
          item = { text: "Hello" }
          result = Transforms.normalize_content_item(item)

          assert_equal "text", result[:type]
          assert_equal "Hello", result[:text]
        end

        test ".normalize_content_item converts image shorthand" do
          item = { image: { data: "..." } }
          result = Transforms.normalize_content_item(item)

          assert_equal "image", result[:type]
          assert_equal({ data: "..." }, result[:source])
          refute result.key?(:image)
        end

        test ".normalize_content_item converts document shorthand" do
          item = { document: { data: "..." } }
          result = Transforms.normalize_content_item(item)

          assert_equal "document", result[:type]
          assert_equal({ data: "..." }, result[:source])
          refute result.key?(:document)
        end

        test ".normalize_content_item handles tool_result" do
          item = { tool_use_id: "123", content: "result" }
          result = Transforms.normalize_content_item(item)

          assert_equal "tool_result", result[:type]
          assert_equal "123", result[:tool_use_id]
        end

        test ".normalize_content_item handles tool_use" do
          item = { id: "123", name: "get_weather", input: {} }
          result = Transforms.normalize_content_item(item)

          assert_equal "tool_use", result[:type]
        end

        test ".normalize_content_item preserves items with type" do
          item = { type: "text", text: "Hello" }
          result = Transforms.normalize_content_item(item)

          assert_equal item, result
        end

        test ".compress_content compresses single text block to string" do
          hash = {
            messages: [
              { role: "user", content: [ { type: "text", text: "Hello" } ] }
            ]
          }

          result = Transforms.compress_content(hash)

          assert_equal "Hello", result[:messages].first[:content]
        end

        test ".compress_content preserves multi-block content" do
          hash = {
            messages: [
              {
                role: "user",
                content: [
                  { type: "text", text: "Hello" },
                  { type: "text", text: "World" }
                ]
              }
            ]
          }

          result = Transforms.compress_content(hash)

          assert_equal 2, result[:messages].first[:content].length
        end

        test ".compress_content preserves non-text content" do
          hash = {
            messages: [
              { role: "user", content: [ { type: "image", source: {} } ] }
            ]
          }

          result = Transforms.compress_content(hash)

          assert_equal 1, result[:messages].first[:content].length
          assert_equal "image", result[:messages].first[:content].first[:type]
        end

        test ".compress_content compresses system single text block" do
          hash = {
            system: [ { type: "text", text: "You are helpful" } ]
          }

          result = Transforms.compress_content(hash)

          assert_equal "You are helpful", result[:system]
        end

        test ".compress_content preserves system multi-block" do
          hash = {
            system: [
              { type: "text", text: "First" },
              { type: "text", text: "Second" }
            ]
          }

          result = Transforms.compress_content(hash)

          assert_equal 2, result[:system].length
        end

        test ".compress_content handles nil hash" do
          result = Transforms.compress_content(nil)
          assert_nil result
        end

        test ".compress_content handles hash without messages" do
          hash = { model: "claude-3" }
          result = Transforms.compress_content(hash)

          assert_equal "claude-3", result[:model]
        end

        test "round-trip: normalize then compress" do
          original = {
            messages: [ { role: "user", content: "Hello" } ],
            system: "You are helpful"
          }

          normalized = Transforms.normalize_params(original)
          compressed = Transforms.compress_content(
            messages: normalized[:messages],
            system: normalized[:system]
          )

          assert_equal "Hello", compressed[:messages].first[:content]
          assert_equal "You are helpful", compressed[:system]
        end
      end
    end
  end
end

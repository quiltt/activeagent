require "test_helper"

class OpenRouterProviderPluginsTest < ActiveSupport::TestCase
  setup do
    @config = {
      "api_key" => "test_key",
      "model" => "openai/gpt-4o-mini"
    }
    @provider = ActiveAgent::GenerationProvider::OpenRouterProvider.new(@config)
  end

  test "prompt_parameters includes plugins when specified" do
    # Create a mock prompt with plugins option
    prompt = mock_prompt_with_plugins

    # Set the prompt on the provider
    @provider.instance_variable_set(:@prompt, prompt)

    # Get the parameters
    params = @provider.send(:prompt_parameters)

    # Verify plugins are included
    assert_equal({
      id: 'file-parser',
      pdf: {
        engine: 'pdf-text'
      }
    }, params[:plugins])
  end

  test "prompt_parameters excludes plugins when not specified" do
    # Create a mock prompt without plugins option
    prompt = mock_prompt_without_plugins

    # Set the prompt on the provider
    @provider.instance_variable_set(:@prompt, prompt)

    # Get the parameters
    params = @provider.send(:prompt_parameters)

    # Verify plugins are not included
    assert_nil params[:plugins]
  end

  test "responses_parameters includes plugins when specified" do
    # Create a mock prompt with plugins option
    prompt = mock_prompt_with_plugins

    # Set the prompt on the provider
    @provider.instance_variable_set(:@prompt, prompt)

    # Get the parameters
    params = @provider.send(:responses_parameters)

    # Verify plugins are included
    assert_equal({
      id: 'file-parser',
      pdf: {
        engine: 'pdf-text'
      }
    }, params[:plugins])
  end

  private

  def mock_prompt_with_plugins
    prompt = OpenStruct.new
    prompt.options = {
      plugins: {
        id: 'file-parser',
        pdf: {
          engine: 'pdf-text'
        }
      }
    }
    prompt.messages = []
    prompt.actions = []
    prompt.output_schema = nil
    prompt
  end

  def mock_prompt_without_plugins
    prompt = OpenStruct.new
    prompt.options = {}
    prompt.messages = []
    prompt.actions = []
    prompt.output_schema = nil
    prompt
  end
end

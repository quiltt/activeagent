class OpenRouterAgent < ApplicationAgent
  layout "agent"
  generate_with :open_router, model: "qwen/qwen3-30b-a3b:free", instructions: "You're a basic Open Router agent."

  def parse_document
    prompt(
      message: params[:message] || "What is the content of this PDF?",
      file_data: params[:file_data],
      plugins: {
        id: "file-parser",
        pdf: {
          engine: "pdf-text"
        }
      }
    )
  end
end

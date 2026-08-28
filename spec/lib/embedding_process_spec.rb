# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe ::DiscourseChatbot::EmbeddingProcess do
  it "uses a custom embedding model name in preference to the model selector" do
    SiteSetting.chatbot_llm_provider = "google_gemini"
    SiteSetting.chatbot_open_ai_token = "embedding-token"
    SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-ada-002"
    SiteSetting.chatbot_open_ai_embeddings_model_custom_name = "provider-embedding-model"
    client = mock
    OpenAI::Client
      .expects(:new)
      .with { |config| config[:access_token] == "embedding-token" }
      .returns(client)
    client
      .expects(:embeddings)
      .with(parameters: { model: "provider-embedding-model", input: "A question to embed" })
      .returns({ "data" => [{ "embedding" => [0.1, 0.2] }] })

    expect(described_class.new.get_embedding_from_api("A question to embed")).to eq([0.1, 0.2])
  end
end

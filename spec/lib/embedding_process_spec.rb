# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe ::DiscourseChatbot::EmbeddingProcess do
  it "uses the selected provider credential and a custom model name" do
    SiteSetting.chatbot_embeddings_provider = "google_gemini"
    SiteSetting.chatbot_google_gemini_token = "embedding-token"
    SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-ada-002"
    SiteSetting.chatbot_open_ai_embeddings_model_custom_name = "provider-embedding-model"
    client = mock
    SiteSetting.chatbot_open_ai_embeddings_model_custom_url = "https://embed.example.com/v1/"
    OpenAI::Client
      .expects(:new)
      .with do |config|
        config[:access_token] == "embedding-token" &&
          config[:uri_base] == "https://embed.example.com/v1/"
      end
      .returns(client)
    embedding = Array.new(described_class::EXPECTED_DIMENSIONS, 0.1)
    client
      .expects(:embeddings)
      .with(parameters: { model: "provider-embedding-model", input: "A question to embed" })
      .returns({ "data" => [{ "embedding" => embedding }] })

    expect(described_class.new.get_embedding_from_api("A question to embed")).to eq(embedding)
  end

  it "selects the Google Gemini embedding model independently of the chat provider" do
    SiteSetting.chatbot_llm_provider = "anthropic"
    SiteSetting.chatbot_embeddings_provider = "google_gemini"
    SiteSetting.chatbot_google_gemini_embeddings_model = "gemini-embedding-2"

    expect(::DiscourseChatbot.embedding_model_name).to eq("gemini-embedding-2")
  end

  it "uses xAI's credential, endpoint, and embedding model" do
    SiteSetting.chatbot_embeddings_provider = "x_ai"
    SiteSetting.chatbot_x_ai_token = "xai-embedding-token"
    SiteSetting.chatbot_x_ai_embeddings_model = "embed-latest"
    embedding = Array.new(described_class::EXPECTED_DIMENSIONS, 0.1)
    client = mock
    OpenAI::Client
      .expects(:new)
      .with do |config|
        config[:access_token] == "xai-embedding-token" &&
          config[:uri_base] == "https://api.x.ai/v1/"
      end
      .returns(client)
    client
      .expects(:embeddings)
      .with(parameters: { model: "embed-latest", input: "A question to embed" })
      .returns({ "data" => [{ "embedding" => embedding }] })

    expect(described_class.new.get_embedding_from_api("A question to embed")).to eq(embedding)
  end

  it "requests a storable vector size from OpenAI's large embedding model" do
    SiteSetting.chatbot_embeddings_provider = "open_ai"
    SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-3-large"
    embedding = Array.new(described_class::EXPECTED_DIMENSIONS, 0.1)
    client = mock
    OpenAI::Client.stubs(:new).returns(client)
    client
      .expects(:embeddings)
      .with(
        parameters: {
          model: "text-embedding-3-large",
          input: "A question to embed",
          dimensions: described_class::EXPECTED_DIMENSIONS,
        },
      )
      .returns({ "data" => [{ "embedding" => embedding }] })

    expect(described_class.new.get_embedding_from_api("A question to embed")).to eq(embedding)
  end

  it "requests a storable vector size when OpenAI's large model uses a custom deployment name" do
    SiteSetting.chatbot_embeddings_provider = "open_ai"
    SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-3-large"
    SiteSetting.chatbot_open_ai_embeddings_model_custom_name = "large-embedding-deployment"
    embedding = Array.new(described_class::EXPECTED_DIMENSIONS, 0.1)
    client = mock
    OpenAI::Client.stubs(:new).returns(client)
    client
      .expects(:embeddings)
      .with(
        parameters: {
          model: "large-embedding-deployment",
          input: "A question to embed",
          dimensions: described_class::EXPECTED_DIMENSIONS,
        },
      )
      .returns({ "data" => [{ "embedding" => embedding }] })

    expect(described_class.new.get_embedding_from_api("A question to embed")).to eq(embedding)
  end

  it "rejects vectors that cannot be stored in the existing embedding columns" do
    client = mock
    OpenAI::Client.stubs(:new).returns(client)
    client.stubs(:embeddings).returns({ "data" => [{ "embedding" => Array.new(1024, 0.1) }] })

    expect { described_class.new.get_embedding_from_api("A question to embed") }.to raise_error(
      described_class::EmbeddingDimensionError,
      "Embedding provider returned 1024 dimensions; expected 1536",
    )
  end

  it "requests 1,536-dimensional vectors from the native Gemini endpoint" do
    SiteSetting.chatbot_embeddings_provider = "google_gemini"
    SiteSetting.chatbot_google_gemini_token = "gemini-embedding-token"
    SiteSetting.chatbot_google_gemini_embeddings_model = "gemini-embedding-001"
    request =
      stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents",
      )
        .with do |http_request|
          body = JSON.parse(http_request.body)
          http_request.headers["X-Goog-Api-Key"] == "gemini-embedding-token" &&
            body.dig("requests", 0, "outputDimensionality") == 1536
        end
        .to_return(body: JSON.generate("embeddings" => [{ "values" => Array.new(1536, 0.1) }]))

    embedding = described_class.new.get_embedding_from_api("A question to embed")

    expect(request).to have_been_requested
    expect(embedding.length).to eq(1536)
  end
end

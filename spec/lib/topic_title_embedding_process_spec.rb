# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe DiscourseChatbot::Topic::TopicTitleEmbeddingProcess do
  subject(:embedding_process) { described_class.new }

  it "requires the stored provider and model to match the current configuration" do
    SiteSetting.chatbot_embeddings_provider = "open_ai"
    SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-ada-002"
    topic = Fabricate(:topic)
    topic_embedding =
      ::DiscourseChatbot::TopicTitleEmbedding.create!(
        topic_id: topic.id,
        model: "text-embedding-ada-002",
        provider: "google_gemini",
        embedding: "[#{Array.new(1536, 0.1).join(",")}]",
      )

    expect(embedding_process.is_valid(topic.id)).to eq(false)

    topic_embedding.update!(provider: "open_ai")

    expect(embedding_process.is_valid(topic.id)).to eq(true)
  end

  it "uses the dimension-aware embedding request path for semantic search" do
    SiteSetting.chatbot_open_ai_embeddings_char_limit = 10
    embedding = Array.new(::DiscourseChatbot::EmbeddingProcess::EXPECTED_DIMENSIONS, 0.1)
    embedding_process.expects(:get_embedding_from_api).with("A long sear").returns(embedding)
    DB.expects(:query).returns([])

    expect(embedding_process.semantic_search("A long search query")).to eq([])
  end
end

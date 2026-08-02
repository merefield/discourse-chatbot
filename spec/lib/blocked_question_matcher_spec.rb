# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe ::DiscourseChatbot::BlockedQuestionMatcher do
  let(:client) { mock }

  it "ships multiple default questions for each default category" do
    examples = SiteSetting.defaults[:chatbot_blocked_question_examples]
    examples = JSON.parse(examples) if examples.is_a?(String)

    expect(examples.map { |example| example["category"] }.tally).to eq(
      "Politics" => 6,
      "Video Games" => 6,
    )
    expect(examples).to all(include("category", "example_question"))
  end

  it "reads examples from the native objects setting value" do
    SiteSetting.stubs(:chatbot_blocked_question_examples).returns(
      [{ "category" => "Politics", "example_question" => "Who should I vote for?" }],
    )
    client.stubs(:embeddings).returns(
      embedding_response([1.0, 0.0]),
      embedding_response([1.0, 0.0]),
    )

    expect(described_class.new.evaluate("Who should I vote for?")).to include(
      blocked: true,
      outcome: "blocked",
      category: "Politics",
    )
  end

  it "uses the default API type and version for non-Azure embedding requests" do
    SiteSetting.chatbot_open_ai_model_custom_api_type = "open_ai"
    OpenAI::Client
      .expects(:new)
      .with { |config| !config.key?(:api_type) && !config.key?(:api_version) }
      .returns(client)

    described_class.new.send(:client)
  end

  it "configures the API type and version for Azure embedding requests" do
    SiteSetting.chatbot_open_ai_model_custom_api_type = "azure"
    SiteSetting.chatbot_open_ai_model_custom_api_version = "2026-01-01"
    OpenAI::Client
      .expects(:new)
      .with { |config| config[:api_type] == :azure && config[:api_version] == "2026-01-01" }
      .returns(client)

    described_class.new.send(:client)
  end

  before do
    SiteSetting.chatbot_blocked_questions_enabled = true
    SiteSetting.chatbot_blocked_questions_similarity_threshold = 0.8
    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Politics", example_question: "Who should I vote for?" },
      { category: "Politics", example_question: "Is the government doing a good job?" },
      { category: "Video games", example_question: "Which console should I buy?" },
    ].to_json

    OpenAI::Client.stubs(:new).returns(client)
  end

  it "returns the category of the closest configured question and caches example embeddings" do
    client
      .expects(:embeddings)
      .with do |request|
        request.dig(:parameters, :model) == SiteSetting.chatbot_open_ai_embeddings_model
      end
      .times(3)
      .returns(
        embedding_response([1.0, 0.0], [0.9, 0.1], [0.0, 1.0]),
        embedding_response([0.9, 0.1]),
        embedding_response([0.05, 0.95]),
      )

    matcher = described_class.new

    expect(matcher.evaluate("What is your view of the government?")).to include(
      blocked: true,
      outcome: "blocked",
      category: "Politics",
      question: "Is the government doing a good job?",
    )
    expect(matcher.evaluate("Recommend a games console")).to include(
      blocked: true,
      outcome: "blocked",
      category: "Video games",
      question: "Which console should I buy?",
    )
  end

  it "allows a question below the configured similarity threshold" do
    SiteSetting.chatbot_blocked_questions_similarity_threshold = 0.9
    client.stubs(:embeddings).returns(
      embedding_response([1.0, 0.0], [0.9, 0.1], [0.0, 1.0]),
      embedding_response([0.7, 0.7]),
    )

    expect(described_class.new.evaluate("How do I bake bread?")).to include(
      blocked: false,
      outcome: "below_threshold",
      threshold: 0.9,
    )
  end

  it "uses new example embeddings after the setting changes" do
    client
      .expects(:embeddings)
      .times(4)
      .returns(
        embedding_response([1.0, 0.0], [0.9, 0.1], [0.0, 1.0]),
        embedding_response([1.0, 0.0]),
        embedding_response([0.0, 1.0]),
        embedding_response([0.0, 1.0]),
      )

    matcher = described_class.new
    expect(matcher.evaluate("Election question")[:category]).to eq("Politics")

    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Sport", example_question: "Who will win the match?" },
    ].to_json

    expect(matcher.evaluate("Football question")[:category]).to eq("Sport")
  end

  it "allows normal processing when the embedding provider returns an error" do
    client.stubs(:embeddings).returns({ "error" => { "message" => "provider unavailable" } })

    expect(described_class.new.evaluate("Who should I vote for?")).to include(
      blocked: false,
      outcome: "error",
      error: "provider unavailable",
    )
  end

  it "does nothing when the feature is disabled" do
    SiteSetting.chatbot_blocked_questions_enabled = false

    expect(described_class.new.evaluate("Who should I vote for?")).to be_nil
  end

  def embedding_response(*vectors)
    {
      "data" =>
        vectors.each_with_index.map { |vector, index| { "index" => index, "embedding" => vector } },
    }
  end
end

# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe DiscourseChatbot::BlockedQuestionMatcher, "#evaluate" do
  let(:url) { "https://api.typesafe.ai/v1/systemone" }
  let(:question) { "Which games console should I buy?" }
  let(:answer) do
    {
      type: "choice",
      choice: "out_of_scope",
      probabilities: {
        in_scope: 0.01,
        out_of_scope: 0.98,
        unclear: 0.01,
      },
      confidence: 0.95,
    }
  end
  let(:response) do
    {
      model: "jev-1.13.0",
      answers: {
        forum_scope: answer,
      },
      usage: {
        input_tokens: 300,
        output_tokens: 30,
      },
    }
  end

  before do
    SiteSetting.chatbot_blocked_questions_enabled = true
    SiteSetting.chatbot_system_one_key = "test-system-one-key"
    SiteSetting.chatbot_blocked_question_examples = "[]"
    SiteSetting.title = "Sailing community"
    SiteSetting.site_description = "Discuss sailing, boats, and life on the water."
  end

  it "uses the default endpoint and model without needing blocked-question examples" do
    request =
      stub_request(:post, url)
        .with(
          headers: {
            "Authorization" => "Bearer test-system-one-key",
            "Content-Type" => "application/json",
          },
        ) do |http_request|
          payload = JSON.parse(http_request.body)
          payload["model"] == "jev-latest" && payload.dig("state", "question") == question &&
            payload.dig("state", "forum", "description") == SiteSetting.site_description &&
            payload.dig("questions", "forum_scope", "type") == "choice"
        end
        .to_return(status: 200, body: response.to_json)

    expect(described_class.new.evaluate(question)).to include(
      blocked: true,
      strategy: "system_one",
      outcome: "system_one_blocked",
      model: "jev-1.13.0",
      probability: 0.98,
      usage: {
        "input_tokens" => 300,
        "output_tokens" => 30,
      },
    )
    expect(request).to have_been_requested.once
  end

  it "sends category metadata and fills all history slots with visible, undeleted regular posts" do
    category =
      Fabricate(:category, name: "Boat maintenance", description: "Care and repair of boats")
    topic = Fabricate(:topic, category: category)
    preceding =
      (1..4).map do |post_number|
        Fabricate(
          :post,
          topic: topic,
          post_number: post_number,
          raw: "Sail repair question #{post_number}",
        )
      end
    (5..8).each do |post_number|
      Fabricate(:post, topic: topic, post_number: post_number, deleted_at: Time.now)
    end
    Fabricate(:post, topic: topic, post_number: 9, hidden: true)
    Fabricate(:post, topic: topic, post_number: 10, post_type: Post.types[:whisper])
    current = Fabricate(:post, topic: topic, post_number: 11, raw: "How much does that cost?")
    Fabricate(:post, topic: topic, post_number: 12)
    request =
      stub_request(:post, url)
        .with do |http_request|
          context = JSON.parse(http_request.body).dig("state", "conversation")
          context ==
            {
              "title" => topic.title,
              "category" => {
                "name" => category.name,
                "description" => category.description_text,
              },
              "preceding_messages" => preceding.map(&:raw),
            }
        end
        .to_return(status: 200, body: response.to_json)

    expect(described_class.new.evaluate(current.raw, submission: current)[:strategy]).to eq(
      "system_one",
    )
    expect(request).to have_been_requested.once
  end

  it "keeps Chat context within the same channel and thread" do
    channel = Fabricate(:chat_channel)
    thread = Fabricate(:chat_thread, channel: channel)
    preceding =
      Fabricate(:chat_message, chat_channel: channel, thread: thread, message: "Repairing a sail")
    Fabricate(:chat_message, chat_channel: channel, message: "Unrelated channel discussion")
    Fabricate(:chat_message, chat_channel: channel, thread: thread, deleted_at: Time.now)
    current =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        thread: thread,
        message: "How much would that cost?",
      )
    Fabricate(:chat_message, chat_channel: channel, thread: thread)
    request =
      stub_request(:post, url)
        .with do |http_request|
          context = JSON.parse(http_request.body).dig("state", "conversation")
          context["preceding_messages"] == [thread.original_message.message, preceding.message] &&
            context.dig("category", "name") == channel.chatable.name
        end
        .to_return(status: 200, body: response.to_json)

    expect(described_class.new.evaluate(current.message, submission: current)[:strategy]).to eq(
      "system_one",
    )
    expect(request).to have_been_requested.once
  end

  it "allows in-scope and unclear decisions, and low-probability out-of-scope decisions" do
    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Video games", example_question: question },
    ].to_json
    stub_request(:post, url).to_return { { status: 200, body: response.to_json } }

    [
      ["in_scope", { in_scope: 0.98, out_of_scope: 0.01, unclear: 0.01 }],
      ["unclear", { in_scope: 0.1, out_of_scope: 0.1, unclear: 0.8 }],
      ["out_of_scope", { in_scope: 0.1, out_of_scope: 0.8, unclear: 0.1 }],
    ].each do |choice, probabilities|
      answer[:choice] = choice
      answer[:probabilities] = probabilities
      expect(described_class.new.evaluate(question)).to include(
        blocked: false,
        strategy: "system_one",
        outcome: "system_one_allowed",
        decision: choice,
      )
    end
  end

  it "blocks at the fixed System One probability threshold independently of cosine similarity" do
    SiteSetting.chatbot_blocked_questions_similarity_threshold = 1
    answer[:probabilities] = { in_scope: 0.05, out_of_scope: 0.9, unclear: 0.05 }
    stub_request(:post, url).to_return(status: 200, body: response.to_json)

    expect(described_class.new.evaluate(question)).to include(blocked: true, threshold: 0.9)
  end

  it "uses a custom System One endpoint and model" do
    SiteSetting.chatbot_system_one_url = "https://system-one.example.com/evaluate"
    SiteSetting.chatbot_system_one_model = "custom-judge"
    request =
      stub_request(:post, SiteSetting.chatbot_system_one_url)
        .with { |http_request| JSON.parse(http_request.body)["model"] == "custom-judge" }
        .to_return(status: 200, body: response.to_json)

    expect(described_class.new.evaluate(question)[:strategy]).to eq("system_one")
    expect(request).to have_been_requested.once
  end

  it "uses existing example matching when any connection setting is blank" do
    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Video games", example_question: question },
    ].to_json
    embedding_client = stub(embeddings: embedding_response([1.0, 0.0]))
    OpenAI::Client.stubs(:new).returns(embedding_client)

    %i[chatbot_system_one_model chatbot_system_one_url chatbot_system_one_key].each do |setting|
      original_value = SiteSetting.public_send(setting)
      SiteSetting.public_send("#{setting}=", "")
      expect(described_class.new.evaluate(question)).to include(
        blocked: true,
        outcome: "blocked",
        category: "Video games",
      )
      SiteSetting.public_send("#{setting}=", original_value)
    end
    expect(WebMock).not_to have_requested(:post, url)
  end

  it "falls back to example matching on provider failures" do
    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Video games", example_question: question },
    ].to_json
    OpenAI::Client.stubs(:new).returns(stub(embeddings: embedding_response([1.0, 0.0])))
    stub_request(:post, url).to_return(status: 503, body: "unavailable")

    expect(described_class.new.evaluate(question)).to include(
      blocked: true,
      outcome: "blocked",
      category: "Video games",
      system_one_fallback: "RuntimeError",
    )
  end

  it "allows normal processing after a timeout when no fallback examples are configured" do
    stub_request(:post, url).to_timeout

    expect(described_class.new.evaluate(question)).to include(
      blocked: false,
      outcome: "no_examples",
      system_one_fallback: a_string_matching(/Faraday::(TimeoutError|ConnectionFailed)/),
    )
  end

  it "falls back on malformed JSON and invalid typed answers" do
    stub_request(:post, url).to_return(
      { status: 200, body: "not JSON" },
      { status: 200, body: { answers: {} }.to_json },
      {
        status: 200,
        body: response.deep_merge(answers: { forum_scope: { type: "noul" } }).to_json,
      },
      {
        status: 200,
        body:
          response.deep_merge(
            answers: {
              forum_scope: {
                probabilities: {
                  out_of_scope: 2,
                },
              },
            },
          ).to_json,
      },
    )

    4.times do
      result = described_class.new.evaluate(question)
      expect(result).to include(blocked: false, outcome: "no_examples")
      expect(result[:system_one_fallback]).to be_present
    end
  end

  it "avoids all provider calls when disabled or given an empty question" do
    expect(described_class.new.evaluate("")).to include(blocked: false, outcome: "empty_question")
    SiteSetting.chatbot_blocked_questions_enabled = false
    expect(described_class.new.evaluate(question)).to be_nil
    expect(WebMock).not_to have_requested(:post, url)
  end
end

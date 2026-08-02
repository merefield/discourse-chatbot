# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::OpenAiBotBasic do
  let(:opts) { {} }
  let(:client) { mock }
  let(:responses_api) { mock }

  before do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.6-sol"
    SiteSetting.chatbot_open_ai_model_reasoning_level = "max"
    SiteSetting.chatbot_open_ai_model_verbosity = "low"

    OpenAI::Client.stubs(:new).returns(client)
    client.stubs(:responses).returns(responses_api)
  end

  it "uses the responses api for reasoning models" do
    client.expects(:chat).never
    responses_api
      .expects(:create)
      .with do |args|
        parameters = args[:parameters]

        expect(parameters[:model]).to eq("gpt-5.6-sol")
        expect(parameters[:reasoning]).to eq({ effort: "max" })
        expect(parameters[:text]).to eq({ verbosity: "low" })
        expect(parameters[:max_output_tokens]).to eq(25_000)
        expect(parameters[:input].first[:role]).to eq("developer")
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "hello world" }],
            },
          ],
          "usage" => {
            "total_tokens" => 42,
          },
        },
      )

    response = described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)

    expect(response[:reply]).to eq("hello world")
  end

  it "returns a responses api refusal as the reply" do
    responses_api.expects(:create).returns(
      {
        "status" => "completed",
        "output" => [
          {
            "type" => "message",
            "content" => [{ "type" => "refusal", "refusal" => "I cannot help with that." }],
          },
        ],
        "usage" => {
          "total_tokens" => 3,
        },
      },
    )

    response = described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)

    expect(response[:reply]).to eq("I cannot help with that.")
  end

  it "rejects a completed responses api response without a message" do
    responses_api.expects(:create).returns(
      {
        "status" => "completed",
        "output" => [],
        "usage" => {
          "total_tokens" => 3,
        },
      },
    )

    expect do
      described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::OpenAIBotBase::ResponsesApiError,
      "OpenAI Responses API completed without visible message content",
    )
  end

  it "raises when the responses api exhausts its budget without visible output" do
    responses_api.expects(:create).returns(
      {
        "status" => "incomplete",
        "incomplete_details" => {
          "reason" => "max_output_tokens",
        },
        "output" => [],
        "usage" => {
          "total_tokens" => 10,
        },
      },
    )

    expect do
      described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::OpenAIBotBase::TokenBudgetError,
      "OpenAI Responses API exhausted chatbot_open_ai_max_reasoning_output_tokens before producing visible output",
    )
  end

  it "returns visible text from an incomplete responses api response" do
    responses_api.expects(:create).returns(
      {
        "status" => "incomplete",
        "incomplete_details" => {
          "reason" => "max_output_tokens",
        },
        "output" => [
          {
            "type" => "message",
            "content" => [{ "type" => "output_text", "text" => "Partial answer" }],
          },
        ],
        "usage" => {
          "total_tokens" => 10,
        },
      },
    )

    response = described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)

    expect(response[:reply]).to eq("Partial answer")
  end

  it "can use provider token defaults for both OpenAI APIs" do
    SiteSetting.chatbot_open_ai_max_reasoning_output_tokens = 0
    responses_api
      .expects(:create)
      .with { |args| !args[:parameters].key?(:max_output_tokens) }
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "Reasoning answer" }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    reasoning_response =
      described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)

    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_max_response_tokens = 0
    client
      .expects(:chat)
      .with { |args| !args[:parameters].key?(:max_completion_tokens) }
      .returns(
        {
          "choices" => [{ "message" => { "content" => "Completion answer" } }],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    completion_response =
      described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)

    expect([reasoning_response[:reply], completion_response[:reply]]).to eq(
      ["Reasoning answer", "Completion answer"],
    )
  end

  it "raises errors returned in a responses api payload" do
    responses_api.expects(:create).returns(
      {
        "status" => "failed",
        "error" => {
          "message" => "The request failed",
        },
      },
    )

    expect do
      described_class.new(opts).get_response([{ role: "user", content: "Hi" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::OpenAIBotBase::ResponsesApiError,
      "OpenAI Responses API error: The request failed",
    )
  end
end

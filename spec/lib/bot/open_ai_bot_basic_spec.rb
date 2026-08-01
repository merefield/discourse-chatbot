# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::OpenAiBotBasic do
  let(:opts) { {} }
  let(:client) { mock }
  let(:responses_api) { mock }

  before do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_open_ai_model_reasoning_level = "high"
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

        expect(parameters[:model]).to eq("gpt-5.4-mini")
        expect(parameters[:reasoning]).to eq({ effort: "high" })
        expect(parameters[:text]).to eq({ verbosity: "low" })
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

  it "raises when the responses api response is incomplete" do
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
      ::DiscourseChatbot::OpenAIBotBase::ResponsesApiError,
      "OpenAI Responses API response was incomplete: max_output_tokens",
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

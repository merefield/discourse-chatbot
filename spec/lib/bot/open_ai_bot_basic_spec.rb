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
end

# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::Vision do
  subject(:vision_tool) { described_class.new }

  it "uses an independent xAI provider with Responses image input" do
    SiteSetting.chatbot_llm_provider = "anthropic"
    SiteSetting.chatbot_vision_provider = "x_ai"
    SiteSetting.chatbot_x_ai_vision_model = "grok-4.6"
    responses = mock
    client = mock(responses: responses)
    responses
      .expects(:create)
      .with do |parameters:|
        parameters[:model] == "grok-4.6" &&
          parameters.dig(:input, 0, :content, 0, :type) == "input_image"
      end
      .returns(
        { "output" => [{ "content" => [{ "type" => "output_text", "text" => "A landscape" }] }] },
      )

    _response, text =
      vision_tool.send(:vision_response, client, "x_ai", "Describe it", "https://example.com/a.png")

    expect(text).to eq("A landscape")
  end

  it "uses the OpenAI-compatible image format for Gemini" do
    SiteSetting.chatbot_vision_provider = "google_gemini"
    SiteSetting.chatbot_google_gemini_vision_model = "gemini-3.7-flash"
    client = mock
    client
      .expects(:chat)
      .with do |parameters:|
        parameters[:model] == "gemini-3.7-flash" &&
          parameters.dig(:messages, 0, :content, 1, :type) == "image_url"
      end
      .returns({ "choices" => [{ "message" => { "content" => "A diagram" } }] })

    _response, text =
      vision_tool.send(
        :vision_response,
        client,
        "google_gemini",
        "Describe it",
        "https://example.com/a.png",
      )

    expect(text).to eq("A diagram")
  end
end

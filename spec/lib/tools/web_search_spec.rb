# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::WebSearch do
  it "limits the response to the configured number of characters" do
    SiteSetting.chatbot_tool_response_char_limit = 5
    stub_request(:get, "https://s.jina.ai/example").to_return(body: "abcdef")

    result = described_class.new.process("query" => "example")

    expect(result[:answer]).to eq("abcde")
  end
end

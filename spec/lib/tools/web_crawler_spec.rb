# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::WebCrawler do
  it "limits the response to the configured number of characters" do
    SiteSetting.chatbot_tool_response_char_limit = 5
    stub_request(:get, "https://r.jina.ai/https://example.com").to_return(body: "abcdef")

    result = described_class.new.process("url" => "https://example.com")

    expect(result[:answer]).to eq("abcde")
  end
end

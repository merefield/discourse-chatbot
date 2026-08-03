# frozen_string_literal: true
require_relative "../plugin_helper"

describe ::DiscourseChatbot::LlmClient do
  after { OpenAI.configuration = OpenAI::Configuration.new }

  it "updates OpenAI error logging when the site setting changes" do
    SiteSetting.chatbot_enable_verbose_rails_logging = "all"
    described_class.new(trust_level: "low")
    expect(OpenAI.configuration.log_errors).to eq(true)

    SiteSetting.chatbot_enable_verbose_rails_logging = "off"
    described_class.new(trust_level: "low")
    expect(OpenAI.configuration.log_errors).to eq(false)
  end
end

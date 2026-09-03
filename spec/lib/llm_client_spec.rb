# frozen_string_literal: true
require_relative "../plugin_helper"

describe ::DiscourseChatbot::LlmClient do
  after { OpenAI.configuration = OpenAI::Configuration.new }

  before do
    SiteSetting.chatbot_open_ai_token = "open-ai-token"
    SiteSetting.chatbot_anthropic_token = "anthropic-token"
    SiteSetting.chatbot_google_gemini_token = "gemini-token"
    SiteSetting.chatbot_x_ai_token = "x-ai-token"
    SiteSetting.chatbot_enable_verbose_rails_logging = "off"
  end

  it "uses OpenAI by default" do
    llm_client = described_class.new(trust_level: "low")

    aggregate_failures do
      expect(llm_client.provider).to eq("open_ai")
      expect(llm_client.client.access_token).to eq("open-ai-token")
      expect(llm_client.client.uri_base).to eq(OpenAI::Configuration::DEFAULT_URI_BASE)
      expect(llm_client.model_name).to eq(SiteSetting.chatbot_open_ai_model_low_trust)
      expect(llm_client.chat_completions_generation_parameters).to eq(
        temperature: 1.0,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0,
      )
    end
  end

  it "uses Anthropic's compatibility endpoint and default model" do
    SiteSetting.chatbot_llm_provider = "anthropic"

    llm_client = described_class.new(trust_level: "medium")

    aggregate_failures do
      expect(llm_client.client.uri_base).to eq("https://api.anthropic.com/v1/")
      expect(llm_client.client.access_token).to eq("anthropic-token")
      expect(llm_client.model_name).to eq("claude-sonnet-5")
      expect(llm_client.chat_completions_generation_parameters).to eq({})
    end
  end

  it "selects provider models independently for each trust level" do
    SiteSetting.chatbot_llm_provider = "anthropic"
    SiteSetting.chatbot_anthropic_model_low_trust = "claude-haiku-4-5"
    SiteSetting.chatbot_anthropic_model_medium_trust = "claude-sonnet-5"
    SiteSetting.chatbot_anthropic_model_high_trust = "claude-opus-5"

    expect(described_class.new(trust_level: "low").model_name).to eq("claude-haiku-4-5")
    expect(described_class.new(trust_level: "medium").model_name).to eq("claude-sonnet-5")
    expect(described_class.new(trust_level: "high").model_name).to eq("claude-opus-5")
  end

  it "uses xAI's compatibility endpoint, credential, model, and parameters" do
    SiteSetting.chatbot_llm_provider = "x_ai"
    SiteSetting.chatbot_x_ai_model_medium_trust = "grok-4.3"

    llm_client = described_class.new(trust_level: "medium")

    aggregate_failures do
      expect(llm_client.client.uri_base).to eq("https://api.x.ai/v1/")
      expect(llm_client.client.access_token).to eq("x-ai-token")
      expect(llm_client.model_name).to eq("grok-4.3")
      expect(llm_client.chat_completions_generation_parameters).to eq(
        temperature: 1.0,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0,
      )
    end
  end

  it "normalizes requests for Google Gemini" do
    SiteSetting.chatbot_llm_provider = "google_gemini"

    llm_client = described_class.new(trust_level: "high")
    parameters =
      llm_client.chat_completions_parameters([{ role: "developer", content: "You are helpful" }])

    aggregate_failures do
      expect(llm_client.client.uri_base).to eq(
        "https://generativelanguage.googleapis.com/v1beta/openai/",
      )
      expect(llm_client.client.access_token).to eq("gemini-token")
      expect(llm_client.model_name).to eq("gemini-3.8-flash")
      expect(llm_client.chat_completions_generation_parameters).to eq({})
      expect(parameters[:messages]).to eq([{ role: "system", content: "You are helpful" }])
    end
  end

  it "uses custom model and URL overrides for the selected provider" do
    SiteSetting.chatbot_llm_provider = "google_gemini"
    SiteSetting.chatbot_open_ai_model_custom_low_trust = true
    SiteSetting.chatbot_open_ai_model_custom_name_low_trust = "gemini-custom"
    SiteSetting.chatbot_open_ai_model_custom_url_low_trust = "https://llm.example.com/v1/"

    llm_client = described_class.new(trust_level: "low")

    aggregate_failures do
      expect(llm_client.client.uri_base).to eq("https://llm.example.com/v1/")
      expect(llm_client.client.access_token).to eq("gemini-token")
      expect(llm_client.model_name).to eq("gemini-custom")
    end
  end

  it "updates provider error logging when the site setting changes" do
    SiteSetting.chatbot_enable_verbose_rails_logging = "all"
    expect(described_class.new(trust_level: "low").client.log_errors).to eq(true)

    SiteSetting.chatbot_enable_verbose_rails_logging = "off"
    expect(described_class.new(trust_level: "low").client.log_errors).to eq(false)
  end
end

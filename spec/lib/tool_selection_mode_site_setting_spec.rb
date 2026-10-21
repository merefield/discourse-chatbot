# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe DiscourseChatbot::ToolSelectionModeSiteSetting do
  it "offers restrict_calls for OpenAI without Azure and retains saved preferences across providers" do
    expect(SiteSetting.chatbot_system_one_tool_selection_mode).to eq("remove_definitions")
    expect(described_class.values.pluck(:value)).to eq(%w[remove_definitions restrict_calls])
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"

    %w[anthropic google_gemini x_ai].each do |provider|
      SiteSetting.chatbot_llm_provider = provider

      expect(described_class.values.pluck(:value)).to eq(["remove_definitions"])
      expect(SiteSetting.chatbot_system_one_tool_selection_mode).to eq("restrict_calls")
      SiteSetting.chatbot_system_one_tool_selection_mode = "remove_definitions"
      expect(SiteSetting.chatbot_system_one_tool_selection_mode).to eq("remove_definitions")
      SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    end

    SiteSetting.chatbot_llm_provider = "open_ai"
    SiteSetting.chatbot_open_ai_model_custom_api_type = "azure"
    expect(described_class.values.pluck(:value)).to eq(["remove_definitions"])
    expect(SiteSetting.chatbot_system_one_tool_selection_mode).to eq("restrict_calls")

    SiteSetting.chatbot_open_ai_model_custom_api_type = ""
    expect(described_class.values.pluck(:value)).to eq(%w[remove_definitions restrict_calls])
    expect(described_class.valid_value?("unknown")).to eq(false)
  end
end

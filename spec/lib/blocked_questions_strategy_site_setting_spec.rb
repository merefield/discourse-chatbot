# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe DiscourseChatbot::BlockedQuestionsStrategySiteSetting do
  it "offers System One only when all connection settings are populated, retaining saved preferences" do
    SiteSetting.chatbot_system_one_key = "test-key"
    expect(described_class.values.pluck(:value)).to eq(%w[system_one examples])

    %i[chatbot_system_one_model chatbot_system_one_url chatbot_system_one_key].each do |setting|
      original = SiteSetting.public_send(setting)
      SiteSetting.public_send("#{setting}=", "")

      expect(described_class.values.pluck(:value)).to eq(["examples"])
      expect(SiteSetting.chatbot_blocked_questions_strategy).to eq("system_one")
      SiteSetting.chatbot_blocked_questions_strategy = "examples"

      SiteSetting.public_send("#{setting}=", original)
      SiteSetting.chatbot_blocked_questions_strategy = "system_one"
      expect(SiteSetting.chatbot_blocked_questions_strategy).to eq("system_one")
    end
  end
end

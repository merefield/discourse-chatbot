# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::Bot do
  it "consumes some tokens" do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_quota_reach_escalation_groups = "3"
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 3000
    SiteSetting.chatbot_quota_medium_trust = 2000
    SiteSetting.chatbot_quota_low_trust = 1000

    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
    event = ::DiscourseChatbot::EventEvaluation.new
    described_class.new.consume_token_quota(user.id, 100)
    expect(event.get_remaining_quota(user.id)).to eq(1900)
  end
end

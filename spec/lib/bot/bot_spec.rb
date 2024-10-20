# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::Bot do
  it "consumes some tokens" do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_quota_basis = "tokens"
    SiteSetting.chatbot_quota_reach_escalation_groups = "3"
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 3000
    SiteSetting.chatbot_quota_medium_trust = 2000
    SiteSetting.chatbot_quota_low_trust = 1000

    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
    event = ::DiscourseChatbot::EventEvaluation.new
    ::DiscourseChatbot::Bot.new.reset_all_quotas
    remaining_quota_field_name = ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD
    described_class.new.consume_quota(user.id, 100)
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(1900)
  end

  it "consumes a query" do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_quota_basis = "queries"
    SiteSetting.chatbot_quota_reach_escalation_groups = "3"
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 300
    SiteSetting.chatbot_quota_medium_trust = 200
    SiteSetting.chatbot_quota_low_trust = 100

    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
    event = ::DiscourseChatbot::EventEvaluation.new
    ::DiscourseChatbot::Bot.new.reset_all_quotas
    remaining_quota_field_name = ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD
    described_class.new.consume_quota(user.id, 100)
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(199)
  end
end

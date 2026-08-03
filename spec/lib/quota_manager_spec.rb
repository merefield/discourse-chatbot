# frozen_string_literal: true
require_relative "../plugin_helper"

describe ::DiscourseChatbot::QuotaManager do
  before do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_quota_basis = "tokens"
    SiteSetting.chatbot_quota_reach_escalation_groups = "3"
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 3000
    SiteSetting.chatbot_quota_medium_trust = 2000
    SiteSetting.chatbot_quota_low_trust = 1000
  end

  it "consumes some tokens" do
    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
    event = ::DiscourseChatbot::EventEvaluation.new
    described_class.new.reset_all
    remaining_quota_field_name = ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(2000)
    described_class.new.consume(user.id, 100)
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(1900)
  end

  it "consumes a query when no token usage is reported" do
    SiteSetting.chatbot_quota_basis = "queries"
    SiteSetting.chatbot_quota_high_trust = 300
    SiteSetting.chatbot_quota_medium_trust = 200
    SiteSetting.chatbot_quota_low_trust = 100

    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
    event = ::DiscourseChatbot::EventEvaluation.new
    described_class.new.reset_all
    remaining_quota_field_name = ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(200)
    described_class.new.consume(user.id, 0)
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(199)
  end

  it "preserves every concurrent deduction" do
    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
    described_class.new.reset_all

    threads = 5.times.map { Thread.new { described_class.new.consume(user.id, 100) } }
    threads.each(&:value)

    remaining_quota_field_name = ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD
    expect(
      ::DiscourseChatbot::EventEvaluation.new.get_remaining_quota(
        user.id,
        remaining_quota_field_name,
      ),
    ).to eq(1500)
  end

  it "creates one quota field during concurrent first use" do
    user = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)

    threads = 5.times.map { Thread.new { described_class.new.consume(user.id, 100) } }
    threads.each(&:value)

    quota_fields =
      UserCustomField.where(
        user_id: user.id,
        name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
      )
    expect(quota_fields.pluck(:value)).to eq(["1500"])
  end
end

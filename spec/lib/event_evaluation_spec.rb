# frozen_string_literal: true
require_relative '../plugin_helper'

CHATBOT_QUERIES_CUSTOM_FIELD = "chatbot_queries"
CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD = "chatbot_queries_quota_reach_escalation_date"

describe ::DiscourseChatbot::EventEvaluation do
  let(:normal_user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  let(:low_trust_user) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  let(:staged_user) { Fabricate(:user, staged: true, refresh_auto_groups: true) }
  let(:high_trust_user) { Fabricate(:user, trust_level: TrustLevel[3], refresh_auto_groups: true) }
  let(:moderator) { Fabricate(:moderator) }

  before(:each) do
    SiteSetting.chatbot_enabled = true
  end

  it "returns the correct trust level for user in high trust group" do
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"

    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.trust_level(high_trust_user.id)).to equal(::DiscourseChatbot::TRUST_LEVELS[2])
  end

  it "returns the correct trust level (nil) for user in no trust group" do
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "12"
    SiteSetting.chatbot_low_trust_groups = ""

    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.trust_level(staged_user.id)).to equal(nil)
  end

  it "returns the correct trust level for user in high trust group" do
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"

    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.trust_level(normal_user.id)).to equal(::DiscourseChatbot::TRUST_LEVELS[1])
  end

  it "returns the correct quota decision if user is in high trust group and is within quota" do
    UserCustomField.create!(user_id: high_trust_user.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 1)
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 3
    SiteSetting.chatbot_quota_medium_trust = 2
    SiteSetting.chatbot_quota_low_trust = 1

    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.over_quota(high_trust_user.id)).to equal(false)
  end

  it "returns the correct quota decision if user is in high trust group and user is outside of quota and escalates" do
    UserCustomField.create!(user_id: high_trust_user.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 3)
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 3
    SiteSetting.chatbot_quota_medium_trust = 2
    SiteSetting.chatbot_quota_low_trust = 1

    event = ::DiscourseChatbot::EventEvaluation.new
    expect { event.over_quota(high_trust_user.id) }.to change { Topic.where(archetype: Archetype.private_message).count }.by(1)
    expect(event.over_quota(high_trust_user.id)).to equal(true)
  end

  it "returns the correct quota decision if user is in high trust group and user is outside of quota but doesn't escalate" do
    UserCustomField.create!(user_id: high_trust_user.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 3)
    UserCustomField.create!(user_id: high_trust_user.id, name: CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD, value: 30.minutes.ago)
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "10"
    SiteSetting.chatbot_quota_high_trust = 3
    SiteSetting.chatbot_quota_medium_trust = 2
    SiteSetting.chatbot_quota_low_trust = 1

    event = ::DiscourseChatbot::EventEvaluation.new
    expect { event.over_quota(high_trust_user.id) }.not_to change { Topic.where(archetype: Archetype.private_message).count }
    expect(event.over_quota(high_trust_user.id)).to equal(true)
  end

  it "returns the correct quota decision if 'everyone' group exists in a chatbot trust level and user has not reached their quota" do
    UserCustomField.create!(user_id: normal_user.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 1)
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "0"
    SiteSetting.chatbot_quota_high_trust = 4
    SiteSetting.chatbot_quota_medium_trust = 3
    SiteSetting.chatbot_quota_low_trust = 2
    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.over_quota(normal_user.id)).to equal(false)
  end

  it "returns the correct quota decision if 'everyone' group exists in a chatbot trust level and user has reached their quota" do
    UserCustomField.create!(user_id: low_trust_user.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 2)
    SiteSetting.chatbot_high_trust_groups = "13|14"
    SiteSetting.chatbot_medium_trust_groups = "11|12"
    SiteSetting.chatbot_low_trust_groups = "0"
    SiteSetting.chatbot_quota_high_trust = 4
    SiteSetting.chatbot_quota_medium_trust = 3
    SiteSetting.chatbot_quota_low_trust = 2
    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.over_quota(low_trust_user.id)).to equal(true)
  end

  it "returns the correct quota decision if staff group exists in a chatbot trust level and user has not reached their quota" do
    UserCustomField.create!(user_id: moderator.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 1)
    SiteSetting.chatbot_high_trust_groups = "3"
    SiteSetting.chatbot_medium_trust_groups = ""
    SiteSetting.chatbot_low_trust_groups = ""
    SiteSetting.chatbot_quota_high_trust = 4
    SiteSetting.chatbot_quota_medium_trust = 3
    SiteSetting.chatbot_quota_low_trust = 2
    Group.refresh_automatic_groups!(:staff)
    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.over_quota(moderator.id)).to equal(false)
  end

  it "returns the correct quota decision if staff group exists in a chatbot trust level and user has reached their quota" do
    UserCustomField.create!(user_id: moderator.id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: 4)
    SiteSetting.chatbot_high_trust_groups = "3"
    SiteSetting.chatbot_medium_trust_groups = ""
    SiteSetting.chatbot_low_trust_groups = ""
    SiteSetting.chatbot_quota_high_trust = 4
    SiteSetting.chatbot_quota_medium_trust = 3
    SiteSetting.chatbot_quota_low_trust = 2
    Group.refresh_automatic_groups!(:staff)
    event = ::DiscourseChatbot::EventEvaluation.new
    expect(event.over_quota(moderator.id)).to equal(true)
  end

end

# frozen_string_literal: true
require_relative "../../plugin_helper"

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
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(2000)
    described_class.new.consume_quota(user.id, 100)
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(1900)
  end

  it "consumes a query when no token usage is reported" do
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
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(200)
    described_class.new.consume_quota(user.id, 0)
    expect(event.get_remaining_quota(user.id, remaining_quota_field_name)).to eq(199)
  end

  it "consumes accumulated tokens when a response fails" do
    SiteSetting.chatbot_quota_basis = "tokens"
    user = Fabricate(:user)
    bot_user = Fabricate(:user)
    post = Fabricate(:post, user: user)
    quota =
      UserCustomField.create!(
        user_id: user.id,
        name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
        value: "100",
      )
    failed_bot_class =
      Class.new(described_class) do
        attr_reader :total_tokens

        define_method(:get_response) do |*|
          @total_tokens = 10
          raise ::DiscourseChatbot::Bots::OpenAiBotBase::TokenBudgetError, "budget reached"
        end
      end
    opts = {
      type: ::DiscourseChatbot::POST,
      user_id: user.id,
      bot_user_id: bot_user.id,
      reply_to_message_or_post_id: post.id,
      original_post_number: post.post_number,
      category_id: post.topic.category_id,
    }

    expect { failed_bot_class.new.ask(opts) }.to raise_error(
      ::DiscourseChatbot::Bots::OpenAiBotBase::TokenBudgetError,
      "budget reached",
    )

    expect(quota.reload.value).to eq("90")
  end
end

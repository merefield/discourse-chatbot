# frozen_string_literal: true

RSpec.describe Jobs::ChatbotReply do
  fab!(:requester, :user)
  fab!(:bot_user, :user)
  fab!(:pm_topic) { Fabricate(:private_message_topic, user: requester, recipient: bot_user) }

  before do
    enable_current_plugin

    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_permitted_in_private_messages = true
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_bot_type_low_trust = "RAG"
    SiteSetting.chatbot_private_message_auto_title = false
  end

  it "does not retry token budget errors" do
    post =
      PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    ::DiscourseChatbot::OpenAiBotRag
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::OpenAIBotBase::TokenBudgetError, "budget reached")

    expect { described_class.new.execute(opts) }.not_to raise_error
  end

  it "retries provider errors" do
    post =
      PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    ::DiscourseChatbot::OpenAiBotRag
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::OpenAIBotBase::ResponsesApiError, "provider failed")

    expect { described_class.new.execute(opts) }.to raise_error(
      ::DiscourseChatbot::OpenAIBotBase::ResponsesApiError,
      "provider failed",
    )
  end
end

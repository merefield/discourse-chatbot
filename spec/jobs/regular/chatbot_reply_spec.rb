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

  it "replies immediately when the token budget is reached" do
    SiteSetting.chatbot_include_inner_thoughts_in_private_messages = true
    post =
      PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"
    summary_text = "I used the available budget to investigate the question."

    ::DiscourseChatbot::OpenAiBotRag
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::OpenAIBotBase::TokenBudgetError, "budget reached")
    ::DiscourseChatbot::OpenAiBotRag
      .any_instance
      .stubs(:inner_thoughts)
      .returns([{ type: "reasoning_summary", content: summary_text }])

    described_class.new.execute(opts)

    replies = pm_topic.posts.order(:post_number).last(2)
    expect(replies.first.raw).to include(summary_text)
    expect(replies.last.raw).to eq(I18n.t("chatbot.errors.token_budget"))
  end

  it "replies immediately when a chain limit is reached" do
    post =
      PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    ::DiscourseChatbot::OpenAiBotRag
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::OpenAIBotBase::ChainLimitError, "iteration limit reached")

    described_class.new.execute(opts)

    expect(pm_topic.posts.order(:post_number).last.raw).to eq(
      I18n.t("chatbot.errors.chain_limit"),
    )
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

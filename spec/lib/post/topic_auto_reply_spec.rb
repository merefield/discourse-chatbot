# frozen_string_literal: true

require_relative "../../plugin_helper"

module DiscourseChatbot::TopicAutoReplySpecHelpers
  def create_post(author, raw: "Can you help with this question?", **attributes)
    PostCreator.create!(author, topic_id: topic.id, raw: raw, skip_validations: true, **attributes)
  end

  def start_conversation
    create_post(user, raw: "Hello @help_bot, can you help?")
    create_post(bot_user, raw: "Yes, how can I help?")
  end
end

describe ::DiscourseChatbot::Post::PostEvaluation, "#trigger_response" do
  include DiscourseChatbot::TopicAutoReplySpecHelpers

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:bot_user) { Fabricate(:user, username: "help_bot") }
  fab!(:other_user, :user)
  let(:topic) { Fabricate(:topic, user: user) }
  let(:evaluation) { described_class.new }

  before do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_bot_user = bot_user.username
  end

  it "allows unlimited follow-ups by default regardless of the configured count" do
    SiteSetting.chatbot_auto_reply_up_to_post_count = 0
    start_conversation
    post = create_post(user)

    expect(SiteSetting.chatbot_unlimited_topic_auto_replies).to eq(true)
    expect(evaluation.trigger_response(post)).to include(human_participants_count: 1)
  end

  it "allows follow-ups through the post-count limit and stops above it" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 3
    start_conversation
    post = create_post(user)

    expect(post.topic.reload.posts_count).to eq(3)
    expect(evaluation.trigger_response(post)).to include(
      reply_to_message_or_post_id: post.id,
      automatic_topic_reply: true,
    )

    create_post(bot_user)
    next_post = create_post(user)
    expect(next_post.topic.reload.posts_count).to eq(5)
    expect(evaluation.trigger_response(next_post)).to eq(false)
  end

  it "requires a mention or direct reply when the limit is zero" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 0
    start_conversation
    post = create_post(user)

    expect(evaluation.trigger_response(post)).to eq(false)
    mentioned_post = create_post(user, raw: "Hello @help_bot, one more question")
    expect(evaluation.trigger_response(mentioned_post)).to include(automatic_topic_reply: false)
    direct_reply = create_post(user, reply_to_post_number: 2)
    expect(evaluation.trigger_response(direct_reply)).to include(automatic_topic_reply: false)
  end

  it "allows explicit mentions and direct replies above a positive limit" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 1
    start_conversation

    mentioned_post = create_post(user, raw: "Hello @help_bot, one more question")
    expect(evaluation.trigger_response(mentioned_post)).to include(automatic_topic_reply: false)
    direct_reply = create_post(user, reply_to_post_number: 2)
    expect(evaluation.trigger_response(direct_reply)).to include(automatic_topic_reply: false)
  end

  it "requires previous bot participation for automatic follow-ups" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 10
    create_post(user)

    expect(evaluation.trigger_response(create_post(user))).to eq(false)
  end

  it "stops automatic follow-ups when a second human has participated in either mode" do
    start_conversation
    create_post(other_user)
    create_post(bot_user)
    post = create_post(user)

    expect(evaluation.trigger_response(post)).to eq(false)
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 100
    expect(evaluation.trigger_response(post)).to eq(false)
  end

  it "ignores the system user when finding the previous participant and counting humans" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 10
    start_conversation
    create_post(Discourse.system_user)
    post = create_post(user)

    expect(evaluation.trigger_response(post)).to include(human_participants_count: 1)
  end

  it "applies the limit to category auto-responses" do
    SiteSetting.chatbot_auto_respond_categories = topic.category_id.to_s
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    post = create_post(user)

    SiteSetting.chatbot_auto_reply_up_to_post_count = 0
    expect(evaluation.trigger_response(post)).to eq(false)
    SiteSetting.chatbot_auto_reply_up_to_post_count = 1
    expect(evaluation.trigger_response(post)).to be_present
  end

  it "preserves private-message invitations and follow-ups when the topic limit is zero" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 0
    topic.update!(archetype: Archetype.private_message, category_id: nil)
    topic.topic_allowed_users.create!(user: user)
    topic.topic_allowed_users.create!(user: bot_user)
    Fabricate(:topic_user, topic: topic, user: bot_user, posted: false)
    first_post = create_post(user)

    expect(evaluation.trigger_response(first_post)).to be_present
    create_post(bot_user)
    expect(evaluation.trigger_response(create_post(user))).to be_present
  end
end

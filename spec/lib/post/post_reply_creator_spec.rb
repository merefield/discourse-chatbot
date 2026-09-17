# frozen_string_literal: true

require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Post::PostReplyCreator, "#create" do
  fab!(:user)
  fab!(:bot_user) { Fabricate(:user, username: "help_bot") }
  fab!(:post) { Fabricate(:post, user: user) }
  let(:answer) { "Here is the answer to your question." }
  let(:reminder) { I18n.t("chatbot.topic_auto_reply_limit_reached", username: bot_user.username) }
  let(:options) do
    {
      bot_user_id: bot_user.id,
      reply_to_message_or_post_id: post.id,
      original_post_number: post.post_number,
      topic_or_channel_id: post.topic_id,
      human_participants_count: 1,
      automatic_topic_reply: true,
      reply: answer,
    }
  end

  before do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_unlimited_topic_auto_replies = false
    SiteSetting.chatbot_auto_reply_up_to_post_count = 2
    SiteSetting.chatbot_private_message_auto_title = false
  end

  it "appends a reminder when this answer leaves no room for an automatic follow-up" do
    described_class.new(options).create

    reply = post.topic.posts.order(:post_number).last
    expect(reply.raw).to eq("#{answer}\n\n#{reminder}")
    expect(post.topic.reload.posts_count).to eq(2)
  end

  it "counts an inner-thoughts post before deciding whether to append the reminder" do
    SiteSetting.chatbot_auto_reply_up_to_post_count = 3
    SiteSetting.chatbot_include_inner_thoughts_in_topics = true
    SiteSetting.chatbot_include_inner_thoughts_in_topics_as_whisper = false

    described_class.new(options).create

    expect(post.topic.posts.order(:post_number).last.raw).to eq("#{answer}\n\n#{reminder}")
    expect(post.topic.reload.posts_count).to eq(3)
  end

  it "omits the reminder when another human post would still be within the limit" do
    SiteSetting.chatbot_auto_reply_up_to_post_count = 3

    described_class.new(options).create

    expect(post.topic.posts.order(:post_number).last.raw).to eq(answer)
  end

  it "omits the reminder for explicit invocations after the limit" do
    options[:automatic_topic_reply] = false

    described_class.new(options).create

    expect(post.topic.posts.order(:post_number).last.raw).to eq(answer)
  end

  it "omits the reminder when unlimited replies are enabled" do
    SiteSetting.chatbot_unlimited_topic_auto_replies = true

    described_class.new(options).create

    expect(post.topic.posts.order(:post_number).last.raw).to eq(answer)
  end

  it "omits the reminder in private messages" do
    post.topic.update!(archetype: Archetype.private_message, category_id: nil)
    post.topic.topic_allowed_users.create!(user: user)
    post.topic.topic_allowed_users.create!(user: bot_user)
    options[:is_private_msg] = true

    described_class.new(options).create

    expect(post.topic.posts.order(:post_number).last.raw).to eq(answer)
  end
end

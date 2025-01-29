# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::PostPromptUtils do
  let(:topic) { Fabricate(:topic) }
  let!(:post_1) { Fabricate(:post, topic: topic, post_type: 1) }
  let!(:post_2) { Fabricate(:post, topic: topic, post_type: 1) }
  let!(:post_3) { Fabricate(:post, topic: topic, post_type: 4) }
  let!(:post_4) { Fabricate(:post, topic: topic, post_type: 1, reply_to_post_number: 1) }
  let!(:post_5) { Fabricate(:post, topic: topic, post_type: 1, reply_to_post_number: 2) }
  let!(:post_6) { Fabricate(:post, topic: topic, post_type: 4) }
  let!(:post_7) { Fabricate(:post, topic: topic, post_type: 1) }
  let!(:post_8) { Fabricate(:post, topic: topic, post_type: 2) }
  let!(:post_9) { Fabricate(:post, topic: topic, post_type: 2) }
  let!(:post_10) { Fabricate(:post, topic: topic, post_type: 1, reply_to_post_number: 7) }
  let!(:post_11) { Fabricate(:post, topic: topic, post_type: 1) }

  let(:auto_category) { Fabricate(:category) }
  let(:topic_in_auto_category) { Fabricate(:topic, category: auto_category) }
  let(:bot_user) { Fabricate(:user, refresh_auto_groups: true) }
  let!(:post_1_auto) { Fabricate(:post, topic: topic_in_auto_category, post_type: 1) }

  before(:each) do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_max_look_behind = 10
  end

  it "captures the right history" do
    SiteSetting.chatbot_include_whispers_in_post_history = false

    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_1.id)
    expect(past_posts.count).to equal(0)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_6.id)
    expect(past_posts.count).to equal(3)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(5)

    post_9.destroy
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(5)
  end

  it "captures the right history when whispers are included" do
    SiteSetting.chatbot_include_whispers_in_post_history = true

    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_1.id)
    expect(past_posts.count).to equal(0)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_6.id)
    expect(past_posts.count).to equal(3)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(6)

    post_9.destroy
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(6)
  end

  it "adds the category specific prompt when in an auto-response category" do
    SiteSetting.chatbot_auto_respond_categories = auto_category.id.to_s
    SiteSetting.chatbot_bot_user = bot_user.username
    text = "hello, world!"
    category_text = CategoryCustomField.create!(category_id: auto_category.id, name: "chatbot_auto_response_additional_prompt", value: text)
    opts = {
      reply_to_message_or_post_id: post_1_auto.id,
      bot_user_id: bot_user.id,
      category_id: auto_category.id,
      original_post_number: 1
    }
    prompt = ::DiscourseChatbot::PostPromptUtils.create_prompt(opts)

    expect(prompt.count).to eq(3)
    expect(prompt[2][:content].to_s).to eq(
      I18n.t("chatbot.prompt.post",
      username: post_1_auto.user.username,
      raw: text))
  end

  it "does not add the category specific prompt when in an auto-response category for subsequent posts" do
    SiteSetting.chatbot_auto_respond_categories = auto_category.id.to_s
    SiteSetting.chatbot_bot_user = bot_user.username
    text = "hello, world!"
    category_text = CategoryCustomField.create!(category_id: auto_category.id, name: "chatbot_auto_response_additional_prompt", value: text)
    opts = {
      reply_to_message_or_post_id: post_1_auto.id,
      bot_user_id: bot_user.id,
      category_id: auto_category.id,
      original_post_number: 2
    }

    prompt = ::DiscourseChatbot::PostPromptUtils.create_prompt(opts)

    expect(prompt.count).to eq(2)
  end
end

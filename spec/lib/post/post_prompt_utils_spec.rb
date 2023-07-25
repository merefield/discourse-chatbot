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

  before(:each) do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_max_look_behind = 10
  end

  it "captures the right history" do
    SiteSetting.chatbot_include_whispers_in_post_history = false

    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_1.id)
    expect(past_posts.count).to equal(1)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_6.id)
    expect(past_posts.count).to equal(4)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(6)

    post_9.destroy
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(6)
  end

  it "captures the right history when whispers are included" do
    SiteSetting.chatbot_include_whispers_in_post_history = true

    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_1.id)
    expect(past_posts.count).to equal(1)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_6.id)
    expect(past_posts.count).to equal(4)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(7)

    post_9.destroy
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_11.id)
    expect(past_posts.count).to equal(7)
  end
end
